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

# for Alfred's Jenkins master to log in and run a slave
jenkins-user-and-group:
    group.present:
        - name: jenkins
        - system: True

    user.present:
        - name: jenkins
        - fullname: Jenkins
        - home: /var/lib/jenkins
        - shell: /bin/bash
        - groups:
            - jenkins
        - require:
            - group: jenkins-user-and-group

# to get all environment variables like PATH
# when executing commands over SSH (which is what Jenkins does
# to start the slave)
jenkins-bashrc-sourcing-profile:
    file.prepend:
        - name: /var/lib/jenkins/.bashrc
        - text:
            - "# to load PATH and env variables in all ssh commands"
            - source /etc/profile
        - require:
            - user: jenkins-user-and-group

jenkins-slave-node-folder:
    file.directory:
        - name: /var/lib/jenkins-libraries-runner
        - user: jenkins
        - group: jenkins
        - dir_mode: 755
        - require:
            - user: jenkins-user-and-group

alfred-jenkins-user-public-key:
    ssh_auth.present:
        - name: jenkins@alfred
        - user: jenkins
        - source: salt://elife-alfred/config/var-lib-jenkins-.ssh-id_rsa.pub
        - require:
            - user: jenkins-user-and-group

# to check out projects on the slave
add-alfred-key-to-jenkins-home:
    file.managed:
        - user: jenkins
        - name: /var/lib/jenkins/.ssh/id_rsa
        - source: salt://elife-alfred/config/var-lib-jenkins-.ssh-id_rsa
        - mode: 400
        - require:
            - ssh_auth: alfred-jenkins-user-public-key

# Jenkins slave does not clean up workspaces after builds are run.
# Cleaning them manually while no build should be running is
# necessary to avoid filling up the disk space or inodes
jenkins-workspaces-cleanup-cron:
    cron.present:
        - user: jenkins
        - name: rm -rf /var/lib/jenkins-libraries-runner/workspace/*
        - identifier: clean-workspaces
        - hour: 5
        - minute: 0

coveralls:
    file.managed:
        - name: /etc/profile.d/coveralls.sh
        - contents: export COVERALLS_REPO_TOKEN={{ elife_libraries.coveralls.github_token }}
