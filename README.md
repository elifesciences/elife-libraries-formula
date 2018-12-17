# `elife-libraries` formula

This repository contains instructions for installing and configuring the `elife-libraries`
project.

This repository should be structured as any Saltstack formula should, but it 
should also conform to the structure required by the [builder](https://github.com/elifesciences/builder) 
project.

See the eLife [builder example project](https://github.com/elifesciences/builder-example-project)
for a reference on how to integrate with the `builder` project.

[MIT licensed](LICENCE.txt)

## Scope

This project produces a Jenkins node with some basic catch-all eLife software installed (PHP, Python, MySQL, Postgres). Its main intent is to run builds of libraries; unlike projects, libraries don't have a dedicated infrastructure or multiple environments to run on.

If a library is tested with the aid of Docker containers, rely on the [`containers`](https://github.com/elifesciences/containers-formula) nodes instead.
