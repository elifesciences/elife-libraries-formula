deployuser-pgpass-file:
    file.managed:
        - user: {{ pillar.elife.deploy_user.username }}
        - name: /home/{{ pillar.elife.deploy_user.username }}/.pgpass
        - source: salt://elife/config/root-pgpass
        - template: jinja
        - mode: 0600
        - defaults:
            user: {{ pillar.elife.db_root.username }}
            pass: {{ pillar.elife.db_root.password }}
            host: localhost
            port: 5432

pattern-library-gulp:
    npm.installed:
        - name: gulp-cli
        - require:
            - pkg: nodejs

project-dependencies:
    pkg.installed:
        - pkgs:
            - make
            # elife-poa-xml-generation
            - libxml2-dev
            - libxslt1-dev
            # article-json, bot-lax, elife-tools
            - libxml2-dev
            - libxslt1-dev
            # elife-metrics
            - libffi-dev
            - libpq-dev
            # elife-cleaner
            - poppler-utils
            - ghostscript
            - libmagickwand-dev

imagemagick-policy:
    file.managed:
        - name: /etc/ImageMagick-6/policy.xml
        - source: salt://elife-libraries/config/etc-ImageMagick-6-policy.xml

elife-metrics-auth:
    file.managed:
        - user: {{ pillar.elife.deploy_user.username }}
        - name: /etc/elife-ga-metrics/client-secrets.json
        - source: salt://elife-libraries/config/etc-elife-ga-metrics-client-secrets.json
        - makedirs: True

{% for project, token in pillar.elife_libraries.coveralls.tokens.items() %}
{% set pname = project|replace("_", "-") %}
coveralls-{{ pname }}:
    file.managed:
        - name: /etc/coveralls/tokens/{{ pname }}
        - contents: {{ pillar.elife_libraries.coveralls.tokens.get(project) }}
        - makedirs: True
        - mode: 644
{% endfor %}

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
        - host: localhost
        - require:
            - mysql-ready

mysql-user-grants:
    mysql_grants.present:
        - user: elife-libraries
        - database: '*.*'
        - grant: all privileges
        - require:
            - mysql-user

ubr-test-app-config:
    file.managed:
        - name: /etc/ubr-test-app.cfg
        - source: salt://elife-libraries/config/etc-ubr-test-app.cfg
        - template: jinja
        - user: {{ pillar.elife.deploy_user.username }}
        - mode: 640

tox:
    cmd.run:
        - name: pip install "tox==2.9.1"
        - require:
            - python-3
