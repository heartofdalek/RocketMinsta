#
#   rmbuild configuration file
#

import shutil


cache_dir = None
output_dir = util.path('release', repo.rm_version)
comment = 'release build'
qcc_flags = '-O2'


if 'fast' not in argv:
    def hook_post_build_pk3(log, pk3_path, **rest):
        util.logged_subprocess(['leanify', str(pk3_path)], logger=log)



def hook_post_build(build_info, log, **rest):
    util.copy('COPYING', build_info.output_dir / 'COPYING.rmrelease')

    def list_rmcustoms():
        strs = []

        for cfg in (repo.modfiles / 'rm-custom').glob('*.cfg'):
            with cfg.open() as f:
                strs.append(
                    "%-20s %s" % (
                        cfg.stem,
                        f.readline().strip()[len('//cfgname:'):]
                    )
                )

        return '\n'.join('           ' + s for s in sorted(strs))

    def list_pk3s():
        strs = []

        for pk3 in build_info.output_dir.glob('*.pk3'):
            if not pk3.name.startswith('zzz-rm-server-'):
                strs.append(pk3.name)

        return '\n'.join('           ' + s for s in sorted(strs))

    with open(str(build_info.output_dir / 'README.rmrelease'), 'w') as f:
        f.write((
            '\n'
            'This is an auto generated %(name)s %(version)s release package, built at %(date)s. Installation:\n'
            '\n'
            '    1) Extract the contents of this package into your Nexuiz data directory (typically ~/.nexuiz/data/)\n'
            '    2) Edit your server config and add the following line at very top:\n'
            '\n'
            '           exec rocketminsta.cfg\n'
            '\n'
            '       If you\'d like to use one of the custom configurations,\n'
            '       add the following at the bottom of your config:\n'
            '\n'
            '           rmcustom NAME_OF_CUSTOM_CONFIG\n'
            '\n'
            '       The following configurations were included at build time:\n'
            '%(rmcustoms)s\n'
            '    3) MAKE SURE that the following packages can be autodownloaded by clients:\n'
            '%(pk3s)s\n'
            '\n'
            '       This package contains all of them\n'
            '    4) Start the server and enjoy\n'
            '\n'
            '\n'
            'RocketMinsta project: http://rocketminsta.net/\n'
        ) % {
            'name': build_info.name,
            'version': build_info.version,
            'date': build_info.date_string,
            'rmcustoms': list_rmcustoms(),
            'pk3s': list_pk3s(),
        })

    aname = shutil.make_archive(
        base_name=str(build_info.output_dir.parent / ('%s_%s' % (build_info.name, build_info.version))),
        format='gztar',
        root_dir=str(build_info.output_dir),
        logger=log,
    )

    log.info('Release build finished: %s', aname)
