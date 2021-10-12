from guietta import _, Gui, Quit
from subprocess import call
import logging
import os

logging.basicConfig(level=os.environ.get("LOGLEVEL", "INFO"), format='SAMGUI: %(asctime)s %(levelname)s %(name)s %(message)s')
log = logging.getLogger(__name__)

class SamGUIException(Exception):
  pass

gui = Gui(
  [ 'Remote host:',      '__remote__', _      ],
  [ 'Hop host:',         '__hop__',    _      ],
  [ 'Download CRAM list:', '__ftp__',    _      ],
  [ 'Local CRAM list:',  '__local__',    _      ],
  [ 'Docker image name:','__docker__', _      ],
  [ 'Data path:',        '__data__',   _      ],
  [ [ 'RunMe' ],         _,            _      ]
)

with gui.RunMe:
  if gui.is_running:

    # Sanity checks
    if gui.hop != '' and gui.remote == '':
        raise SamGUIException('Hop host but no remote host supplied.')
    if gui.data == '':
      raise SamGUIException('Data path not supplied')
    if gui.ftp != '' and gui.local != '':
      raise SamGUIException('Requested FTP download but also supplied local CRAM list')
    else if gui.ftp == '' and gui.local == '':
      raise SamGUIException('Did not request FTP download nor supplied local CRAM list')

    # Defaults
    if gui.docker == '':
      log.info('No docker image supplied, using afarah1/ubuntu-samtools')
      gui.docker = 'afarah1/ubuntu-samtools'
    
    # Prepare the remote env and cmd
    remote_cmd=''
    if gui.remote != '':
      log.info('Preparing remote environment at', gui.remote, 'with hop to', gui.hop)
      call('./prepare.sh %s %s %s' % (gui.remote, gui.data, gui.hop), shell=True)
      remote_cmd = './exec_remote.sh -r ' + gui.remote
      if gui.hop != '':
        remote_cmd += ' -J ' + gui.hop
      remote_cmd += ' exec_docker.sh ' + gui.docker + ' ' + gui.data
    else:
      raise SamGUIException('Local execution unsupported') # TODO
    call(remote_cmd + ' mkdir /DATA/data 2>/dev/null', shell=True)
    call(remote_cmd + ' mkdir /DATA/results 2>/dev/null', shell=True)
    if gui.local != '':
      call(remote_cmd + ' mv /DATA/' + gui.local ' /DATA/data/cramlist_local', shell=True)

    # Obtain files from FTP
    if gui.ftp != '':
      log.info('Obtaining CRAMs from remote host', gui.ftp)
      download_cmd = ' /DATA/download_data.sh /DATA/data /DATA/cramlist_remote' 
      call(remote_cmd + download_cmd, shell=True)

    # Run!
    call_cmd = '/DATA/variant_call.sh /DATA /DATA/data/cramlist_local' 
    call(remote_cmd + call_cmd)

gui.run()
