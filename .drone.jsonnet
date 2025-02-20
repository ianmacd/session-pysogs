local docker_base = 'registry.oxen.rocks/lokinet-ci-';
local apt_get_quiet = 'apt-get -o=Dpkg::Use-Pty=0 -q';

local default_deps = [
  'python3',
  'python3-pytest',
  'python3-oxenmq',
  'python3-oxenc',
  'python3-pyonionreq',
  'python3-coloredlogs',
  'python3-uwsgidecorators',
  'python3-flask',
  'python3-cryptography',
  'python3-nacl',
  'python3-pil',
  'python3-protobuf',
  'python3-openssl',
  'python3-qrencode',
  'python3-better-profanity',
  'python3-sqlalchemy',
];

local apt_get_quiet = 'apt-get -o=Dpkg::Use-Pty=0 -q';

// Regular build on a debian-like system:
local debian_pipeline(name,
                      image,
                      arch='amd64',
                      deps=default_deps,
                      extra_cmds=[],
                      allow_fail=false) = {
  kind: 'pipeline',
  type: 'docker',
  name: name,
  platform: { arch: arch },
  trigger: { branch: { exclude: ['debian/*', 'ubuntu/*'] } },
  steps: [
    {
      name: '🐍 pytest',
      image: image,
      pull: 'always',
      [if allow_fail then 'failure']: 'ignore',
      commands: [
                  'echo "Running on ${DRONE_STAGE_MACHINE}"',
                  'echo "man-db man-db/auto-update boolean false" | debconf-set-selections',
                  apt_get_quiet + ' update',
                  apt_get_quiet + ' install -y eatmydata',
                  'eatmydata ' + apt_get_quiet + ' install --no-install-recommends -y lsb-release',
                  'cp contrib/deb.oxen.io.gpg /etc/apt/trusted.gpg.d',
                  'echo deb http://deb.oxen.io $$(lsb_release -sc) main >/etc/apt/sources.list.d/oxen.list',
                  'eatmydata ' + apt_get_quiet + ' update',
                  'eatmydata ' + apt_get_quiet + ' dist-upgrade -y',
                  'eatmydata ' + apt_get_quiet + ' install --no-install-recommends -y ' + std.join(' ', deps),
                  'PYTHONPATH=. python3 -mpytest -vv --color=yes --sql-tracing',
                ]
                + extra_cmds,
    },
  ],
};

[
  {
    name: 'Lint checks',
    kind: 'pipeline',
    type: 'docker',
    platform: { arch: 'amd64' },
    steps: [
      {
        name: 'Formatting',
        image: docker_base + 'debian-stable',
        commands: [
          'echo "Running on ${DRONE_STAGE_MACHINE}"',
          apt_get_quiet + ' install -y black',
          'black --check --diff --color .',
        ],
      },
      {
        name: 'Flake8',
        image: docker_base + 'debian-stable',
        commands: [
          'echo "Running on ${DRONE_STAGE_MACHINE}"',
          apt_get_quiet + ' install -y flake8',
          'flake8 .',
        ],
      },
    ],
  },

  debian_pipeline('Debian sid (amd64)', docker_base + 'debian-sid'),
  debian_pipeline('Debian stable (i386)', docker_base + 'debian-stable/i386'),
  debian_pipeline('Debian stable (amd64)', docker_base + 'debian-stable'),
  debian_pipeline('Ubuntu latest (amd64)', docker_base + 'ubuntu-rolling'),
  debian_pipeline('Ubuntu LTS (amd64)', docker_base + 'ubuntu-lts'),

  // ARM builds (ARM64 and armhf)
  debian_pipeline('Debian sid (ARM64)', docker_base + 'debian-sid', arch='arm64'),
  debian_pipeline('Debian stable (armhf)', docker_base + 'debian-stable/arm32v7', arch='arm64'),

  // Macos:
  {
    kind: 'pipeline',
    type: 'exec',
    name: 'MacOS',
    platform: { os: 'darwin', arch: 'amd64' },
    steps: [
      {
        name: '🐍 pytest',
        commands: [
          'echo "Running on ${DRONE_STAGE_MACHINE}"',
          'PYTHONPATH=. /opt/local/bin/python3 -mpytest -vv --color=yes --sql-tracing',
        ],
      },
    ],
  },
]
