from guietta import _, Gui, Quit
from subprocess import call

class SamGUIException(Exception):
  pass

gui = Gui(
  [ 'Remote host:',      '__remote__', _      ],
  [ 'Hop host:',         '__hop__',    _      ],
  [ 'Remote CRAM list:', '__ftp__',    _      ],
  [ 'Local CRAM list:',  '__local__',  _      ],
  [ [ 'RunMe' ],         _,            _      ]
)

with gui.RunMe:
  if gui.is_running:
    
    # Prepare the remote env and cmd
    remote_cmd=''
    if gui.remote != '':
      print('GUI: Preparing remote environment at', gui.remote, 'with hop to', gui.hop)
      call('./prepare.sh %s %s' % (gui.remote, gui.hop), shell=True)
      remote_cmd = './exec_remote.sh -r ' + gui.remote
      if gui.hop != '':
        remote_cmd += ' -J ' + gui.hop
      remote_cmd += ' exec_docker.sh ubuntu-samtools'
    else:
      raise SamGUIException('Local execution unsupported') # TODO

    # Obtain files from FTP
    if gui.ftp != '':
      print('GUI: Obtaining CRAMs from remote host', gui.ftp)
      download_cmd = ' /DATA/alef/samgui_test/download_data.sh /DATA/alef/samgui_test/data /DATA/alef/samgui_test/cramlist_remote' # TODO fix paths
      call(remote_cmd + download_cmd, shell=True)
    elif gui.local != '':
      raise SamGUIException('Local files unsupported') # TODO
    else:
      raise SamGUIException('No remote nor local CRAM list supplied.')

    # Run!
    call_cmd = '/DATA/alef/samgui_test/variant_call.sh /DATA/alef/samgui_test /DATA/alef/samgui_test/data/cramlist_local' # TODO fix paths
    call(remote_cmd + call_cmd)

gui.run()
