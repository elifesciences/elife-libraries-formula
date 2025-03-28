# lsh@2023-03-28: extracted from elife-alfred/init.sls

builder-non-interactive:
    file.append:
        - name: /etc/environment
        - text: "BUILDER_NON_INTERACTIVE=1"
        - unless:
            - grep 'BUILDER_NON_INTERACTIVE=1' /etc/environment

builder-highstate-no-colours:
    file.append:
        - name: /etc/environment
        - text: "SALT_NO_COLOR=1"
        - unless:
            - grep 'SALT_NO_COLOR=1' /etc/environment

builder-project-dependencies:
    pkg.installed:
        - pkgs:
            - make
            - gcc

builder-project:
    builder.git_latest:
        - name: ssh://git@github.com/elifesciences/builder.git
        - identity: {{ pillar.elife.projects_builder.key or '' }}
        - rev: master
        - force_fetch: True
        - force_reset: True
        - target: /srv/builder
        - require:
            - builder-project-dependencies

    file.directory:
        - name: /srv/builder
        - user: {{ pillar.elife.deploy_user.username }}
        - group: {{ pillar.elife.deploy_user.username }}
        - recurse:
            - user
            - group
        - require:
            - builder: builder-project

builder-update:
    file.touch:
        - name: /srv/builder/.no-delete-venv.flag
        - require:
            - builder-project

    cmd.run:
        # mise exec to create the venv with version of python specified in the .python-version file
        - name: mise install && mise exec -- ./update.sh --exclude virtualbox vagrant ssh-agent ssh-credentials vault terraform
        - cwd: /srv/builder
        - runas: {{ pillar.elife.deploy_user.username }}
        - require:
            - aws-credentials-deploy-user # builder-base.aws-credentials
            - file: builder-update
            - mise-pkg

builder-logrotate:
    file.managed:
        - name: /etc/logrotate.d/builder
        - source: salt://elife-libraries/config/etc-logrotate.d-builder
