format-external-volume:
    cmd.run: 
        - name: mkfs -t ext4 /dev/xvdh
        - onlyif:
            # disk exists
            - test -b /dev/xvdh
        - unless:
            # volume exists and is already formatted
            - file --special-files /dev/xvdh | grep ext4

mount-point-external-volume:
    file.directory:
        - name: /ext

mount-external-volume:
    mount.mounted:
        - name: /ext
        - device: /dev/xvdh
        - fstype: ext4
        - mkmnt: True
        - opts:
            - defaults
        - require:
            - format-external-volume
            - mount-point-external-volume
        - onlyif:
            # disk exists
            - test -b /dev/xvdh
        - unless:
            # mount point already has a volume mounted
            - cat /proc/mounts | grep --quiet --no-messages /ext/

libraries-runner-directory:
    file.directory:
        - name: /ext/jenkins-libraries-runner
        - user: {{ pillar.elife.deploy_user.username }}
        - group: {{ pillar.elife.deploy_user.username }}
        - dir_mode: 755
        - require:
            - deploy-user
            - mount-external-volume

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

elife-article-json-hence-jats-scraper-dependencies:
    pkg.installed:
        - pkgs:
            - libxml2-dev #  jats-scraper
            - libxslt1-dev #  jats-scraper

metrics-dependencies:
    pkg.installed:
        - pkgs:
            - libffi-dev # elife-ga-metrics requirement
            - libpq-dev  #  elife-metrics

elife-ga-metrics-auth:
    file.managed:
        - user: {{ pillar.elife.deploy_user.username }}
        - name: /etc/elife-ga-metrics/client-secrets.json
        - source: salt://elife-libraries/config/etc-elife-ga-metrics-client-secrets.json
        - makedirs: True

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
        - require:
            - deploy-user

jenkins-slave-node-folder:
    file.symlink:
        - name: /var/lib/jenkins-libraries-runner
        - target: /ext/jenkins-libraries-runner
        - user: {{ pillar.elife.deploy_user.username }}
        - group: {{ pillar.elife.deploy_user.username }}
        - require:
            - libraries-runner-directory

# to check out projects on the slave
# the paths are referring to /var/lib/jenkins because it's the path on the master

add-alfred-private-key-to-deploy-user:
    file.managed:
        - user: {{ pillar.elife.deploy_user.username }}
        - name: /home/{{ pillar.elife.deploy_user.username }}/.ssh/id_rsa
        - source: salt://elife-alfred/config/var-lib-jenkins-.ssh-id_rsa
        - mode: 400
        - require:
            - deploy-user

add-alfred-public-key-to-deploy-user:
    file.managed:
        - user: {{ pillar.elife.deploy_user.username }}
        - name: /home/{{ pillar.elife.deploy_user.username }}/.ssh/id_rsa.pub
        - source: salt://elife-alfred/config/var-lib-jenkins-.ssh-id_rsa.pub
        - mode: 400
        - require:
            - deploy-user

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
# TODO: how to remove the duplicate replace()?
coveralls-{{ project|replace("_", "-") }}:
    file.managed:
        - name: /etc/coveralls/tokens/{{ project|replace("_", "-") }}
        - contents: {{ pillar.elife_libraries.coveralls.tokens.get(project) }}
        - makedirs: True
        - mode: 644
{% endfor %}

add-jenkins-gitconfig:
    file.managed:
        - name: /home/{{ pillar.elife.deploy_user.username }}/.gitconfig
        - source: salt://elife-libraries/config/home-deploy-user-.gitconfig
        - mode: 664

# can grow up to 1-2 GB
remove-old-pdepend-caches:
    cron.present:
        - user: {{ pillar.elife.deploy_user.username }}
        - identifier: remove-old-pdepend-caches
        - name: find /home/{{ pillar.elife.deploy_user.username }}/.pdepend -amin +1440 -exec rm {} \;
        - minute: random

# for faster builds
cached-repositories:
    file.directory:
        - name: /ext/cached-repositories
        - user: {{ pillar.elife.deploy_user.username }}
        - group: {{ pillar.elife.deploy_user.username }}
        - mode: 755

    git.latest:
        - name: ssh://git@github.com/elifesciences/elife-article-xml.git
        - user: {{ pillar.elife.deploy_user.username }}
        - rev: master
        - force_fetch: True
        - force_clone: True
        - force_reset: True
        - target: /ext/cached-repositories/elife-article-xml
        - require:
            - file: cached-repositories

cached-repositories-link:
    file.symlink:
        - name: /home/{{ pillar.elife.deploy_user.username }}/elife-article-xml
        - target: /ext/cached-repositories/elife-article-xml
        - user: {{ pillar.elife.deploy_user.username }}
        - group: {{ pillar.elife.deploy_user.username }}
        - require:
            - cached-repositories

aws-credentials:
    file.managed:
        - name: /home/{{ pillar.elife.deploy_user.username }}/.aws/credentials
        - source: salt://elife-libraries/config/home-deploy-user-.aws-credentials
        - template: jinja
        - makedirs: True
        - user: {{ pillar.elife.deploy_user.username }}
        - group: {{ pillar.elife.deploy_user.username }}
        - require:
            - deploy-user

mysql-user:
    mysql_user.present:
        - name: elife-libraries
        - password: elife-libraries
        - connection_pass: {{ pillar.elife.db_root.password }}
        - host: localhost
        - require:
            - mysql-ready
