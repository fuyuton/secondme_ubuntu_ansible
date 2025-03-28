#!/bin/bash
# setup-second-me.sh

# エラー発生時に停止
set -e

echo "===== Second-Me セットアップスクリプト ====="

# Ansibleがインストールされているか確認
if ! command -v ansible &> /dev/null; then
    echo "Ansibleをインストールしています..."
    sudo apt-get update
    sudo apt-get install -y software-properties-common
    sudo apt-add-repository --yes --update ppa:ansible/ansible
    sudo apt-get install -y ansible
fi

# ディレクトリの作成
DEPLOY_DIR="$HOME/second-me-deploy"
mkdir -p "$DEPLOY_DIR"
cd "$DEPLOY_DIR"

# プレイブックの作成
echo "プレイブックファイルを作成しています..."
cat > local-second-me-playbook.yml << 'EOF'
---
# local-second-me-playbook.yml
- name: Deploy Second-Me on Local Ubuntu 24.04 Server
  hosts: localhost
  connection: local
  become: yes
  vars:
    app_dir: /opt/second-me
    build_dir: "{{ app_dir }}/build"
    repo_url: https://github.com/mindverse/Second-Me.git

  tasks:
    - name: Update apt cache
      apt:
        update_cache: yes
        cache_valid_time: 3600

    - name: Upgrade all packages
      apt:
        upgrade: full

    - name: Install required dependencies
      apt:
        name:
          - git
          - build-essential
          - cmake
          - python3
          - python3-pip
          - python3-venv
          - nodejs
          - npm
          - libopencv-dev
          - libglew-dev
          - libglfw3-dev
          - libgles2-mesa-dev
          - libglm-dev
          - libglvnd-dev
          - libeigen3-dev
          - libglu1-mesa-dev
          - freeglut3-dev
          - mesa-common-dev
          - wget
          - unzip
          - ffmpeg
        state: present

    - name: Python仮想環境の作成
      command: python3.12 -m venv /home/fuyuton/secondme/python-project_env
      args:
        creates: /home/fuyuton/secondme/python-project_env/bin/activate

    - name: Install Python dependencies
      pip:
        name:
          - numpy
          - opencv-python
          - transformers
          - torch
          - scikit-learn
        virtualenv: /home/fuyuton/secondme/python-project_env
        virtualenv_python: python3.12
        state: present

    - name: Create app directory
      file:
        path: "{{ app_dir }}"
        state: directory
        mode: '0755'

    - name: Clone Second-Me repository
      git:
        repo: "{{ repo_url }}"
        dest: "{{ app_dir }}"
        clone: yes
        update: yes

    - name: Create build directory
      file:
        path: "{{ build_dir }}"
        state: directory
        mode: '0755'

    - name: Configure project with CMake
      command: cmake ..
      args:
        chdir: "{{ build_dir }}"
        creates: "{{ build_dir }}/Makefile"

    - name: Build project with make
      command: make -j$(nproc)
      args:
        chdir: "{{ build_dir }}"

    - name: Create systemd service file
      copy:
        dest: /etc/systemd/system/second-me.service
        content: |
          [Unit]
          Description=Second-Me Service
          After=network.target

          [Service]
          Type=simple
          User=root
          WorkingDirectory={{ app_dir }}
          ExecStart={{ build_dir }}/second-me
          Restart=always
          RestartSec=3

          [Install]
          WantedBy=multi-user.target
        mode: '0644'

    - name: Reload systemd
      systemd:
        daemon_reload: yes

    - name: Enable and start Second-Me service
      systemd:
        name: second-me
        enabled: yes
        state: started

    - name: Check if Second-Me is running
      command: systemctl status second-me
      register: service_status
      changed_when: false
      ignore_errors: yes

    - name: Display service status
      debug:
        msg: "{{ service_status.stdout_lines }}"
EOF

# Ansibleのホスト設定
echo "Ansibleホスト設定を作成しています..."
cat > ansible.cfg << 'EOF'
[defaults]
inventory = ./hosts
host_key_checking = False
EOF

# インベントリファイルの作成
echo "インベントリファイルを作成しています..."
cat > hosts << 'EOF'
[local]
localhost ansible_connection=local
EOF

echo "セットアップが完了しました。次のコマンドを実行してSecond-Meをインストールします："
echo "cd $DEPLOY_DIR && ansible-playbook local-second-me-playbook.yml --ask-become-pass"
