pattern-library-gulp:
    npm.installed:
        - name: gulp-cli
        - require:
            - pkg: nodejs

make:
    pkg.installed

ruby-dev:
    pkg.installed

pattern-library-compass:
    gem.installed:
        - name: compass
        - require:
            - pkg: ruby-dev
            - pkg: make

patterns-php-composer-1.0:
   cmd.run:
        - name: |
            cp composer composer1.0
            composer1.0 self-update 1.0.3
        - cwd: /usr/local/bin/
        - require:
            - cmd: install-composer
        - unless:
            - which composer1.0

patterns-php-puli-latest:
   cmd.run:
        - name: |
            curl https://puli.io/installer | php
            mv puli.phar puli
        - cwd: /usr/local/bin/
        - unless:
            - which puli

elife-poa-xml-generation-dependencies:
    pkg.installed:
        - pkgs:
            - libxml2-dev
            - libxslt1-dev

# for Alfred's Jenkins master to log in and run a slave: it will use the elife user

# to get all environment variables like PATH
# when executing commands over SSH (which is what Jenkins does
# to start the slave)
jenkins-bashrc-sourcing-profile:
    file.prepend:
        - name: /home/{{ pillar.elife.deploy_user.username }}/.bashrc
        - text:
            - "# to load PATH and env variables in all ssh commands"
            - source /etc/profile
            - deploy-user

jenkins-slave-node-folder:
    file.directory:
        - name: /var/lib/jenkins-libraries-runner
        - user: {{ pillar.elife.deploy_user.username }}
        - group: {{ pillar.elife.deploy_user.username }}
        - dir_mode: 755
        - file_mode: 644
        - recurse:
            - user
            - group
            - mode
        - require:
            - deploy-user

# to check out projects on the slave
add-alfred-key-to-jenkins-home:
    file.managed:
        - user: {{ pillar.elife.deploy_user.username }}
        - name: /home/{{ pillar.elife.deploy_user.username }}/.ssh/id_rsa
        - source: salt://elife-alfred/config/var-lib-jenkins-.ssh-id_rsa
        - mode: 400
        - require:
            - ssh_auth: alfred-jenkins-user-public-key

# Jenkins slave does not clean up workspaces after builds are run.
# Cleaning them manually while no build should be running is
# necessary to avoid filling up the disk space or inodes
jenkins-workspaces-cleanup-cron:
    cron.present:
        - user: {{ pillar.elife.deploy_user.username }}
        - name: rm -rf /var/lib/jenkins-libraries-runner/workspace/*
        - identifier: clean-workspaces
        - hour: 5
        - minute: 0

{% for project, token in pillar.elife_libraries.coveralls.tokens.items() %}
coveralls:
    file.managed:
        - name: /etc/coveralls/tokens/{{ project|replace("_", "-") }}
        - contents: {{ pillar.elife_libraries.coveralls.tokens.elife_poa_xml_generation }}
        - makedirs: True
        - mode: 644
{% endfor %}

add-jenkins-gitconfig:
    file.managed:
        - name: /home/{{ pillar.elife.deploy_user.username }}/.gitconfig
        - source: salt://elife-libraries/config/home-deploy-user-.gitconfig
        - mode: 664
