from guietta import _, ___, Gui, Quit
try:
  from PySide2.QtWidgets import QMessageBox
except ImportError:
  from PyQt5.QtWidgets import QMessageBox
from subprocess import call
import logging
import os

logging.basicConfig(level=os.environ.get("LOGLEVEL", "INFO"), format='SAMGUI: %(asctime)s %(levelname)s %(name)s %(message)s')
log = logging.getLogger(__name__)

class SamGUIException(Exception):
  pass

g_refMsg = ', refer to command line output for details.'

gui = Gui(
  [ 'Remote host*', '__remote__', (['Help'], 'help_remote'), 'Hop host', '__hop__', (['Help'], 'help_hop') ],
  [ 'Download CRAM list', '__ftp__', (['Help'], 'help_ftp'), 'Local CRAM list', '__local__', (['Help'], 'help_local')],
  [ 'Docker image name*','__docker__', (['Help'], 'help_docker'), 'Data path*', '__data__', (['Help'], 'help_data') ],
  [ 'VCF filter params*','__vcffilter__', ___ , ___, ___, ___],
  [ [ 'RunMe' ], _, _, _, _, _]
)

with gui.help_remote:
  if gui.is_running:
    log.debug('help_remote pressed')
    QMessageBox.information(None, "Info", "Remote host where the variant calling pipeline should be executed. Format: user@hostname.") 

with gui.help_hop:
  if gui.is_running:
    log.debug('help_hop pressed')
    QMessageBox.information(None, "Info", "Optional - host to hop through to get to the remote host. Format: user@hostname.")

with gui.help_ftp:
  if gui.is_running:
    log.debug('help_ftp pressed')
    QMessageBox.information(None, "Info", "Optional - list of URLs to download CRAMs from. If not supplied, you must supply a local CRAM list.")

with gui.help_local:
  if gui.is_running:
    log.debug('help_local pressed')
    QMessageBox.information(None, "Info", "Optional - list of CRAM, FASTA, VCF.GZ, and TBI/CSI files already present on the remote host to be used. If not supplied, you must supply a remote CRAM list to download from.")

with gui.help_docker:
  if gui.is_running:
    log.debug('help_docker pressed')
    QMessageBox.information(None, "Info", "Docker image name to be used. Must be present on the remote host or able to pull from a public repo configured on the host.")

with gui.help_data:
  if gui.is_running:
    log.debug('help_data pressed')
    QMessageBox.information(None, "Info", "Path on the remote host where the data is or will be once downloaded. A mount point to this location will be accessed from docker.")

def validate_input(gui):
  if gui.remote == '':
    raise SamGUIException('Local execution not supported :(')
  if gui.hop != '' and gui.remote == '':
      raise SamGUIException('Hop host but no remote host supplied.')
  if gui.data == '':
    raise SamGUIException('Data path not supplied')
  if gui.ftp != '' and gui.local != '':
    raise SamGUIException('Requested FTP download but also supplied local CRAM list')
  elif gui.ftp == '' and gui.local == '':
    raise SamGUIException('Did not request FTP download nor supplied local CRAM list')
  # Defaults
  if gui.docker == '':
    log.info('No docker image supplied, using afarah1/ubuntu-samtools')
    gui.docker = 'afarah1/ubuntu-samtools'

def prepare_env(gui):
  log.info('Preparing remote environment ' + gui.remote + ' with hop to ' + gui.hop)
  remote_cmd=''
  # Copy the necessary files to the remote host
  rc = call('./prepare.sh %s %s %s' % (gui.remote, gui.data, gui.hop), shell=True)
  if rc != 0:
    raise SamGUIException('Remote host preparation failed' + g_refMsg)
  # Build the remote exec cmd
  remote_cmd = './exec_remote.sh -r ' + gui.remote
  if gui.hop != '':
    remote_cmd += ' -J ' + gui.hop
  remote_cmd += ' --'
  # Validate the remote host
  rc = call(remote_cmd + ' prepare_docker.sh ' + gui.docker, shell=True)
  if rc != 0:
    raise SamGUIException('Remote host docker preparation failed' + g_refMsg)
  # Docker is ok, finish building the remote exec cmd
  remote_cmd += ' exec_docker.sh ' + gui.docker + ' ' + gui.data
  # Create the necessary directory structure
  rc = call(remote_cmd + ' mkdir -p /DATA/data', shell=True)
  if rc != 0:
    raise SamGUIException('Could not create remote directory structure' + g_refMsg)
  call(remote_cmd + ' mkdir -p /DATA/results', shell=True)
  if gui.local != '':
    call(remote_cmd + ' mv /DATA/' + gui.local + ' /DATA/data/cramlist_local', shell=True)
  return remote_cmd

def download_files(remote_cmd):
  log.info('Obtaining CRAMs from remote host')
  download_cmd = ' /DATA/download_data.sh /DATA/data /DATA/cramlist_remote'
  call(remote_cmd + download_cmd, shell=True)

with gui.RunMe:
  if gui.is_running:
    log.info('Run requested.')
    validate_input(gui)
    remote_cmd = prepare_env(gui)
    if gui.ftp != '':
      download_files(remote_cmd)
    call_cmd = ' /DATA/variant_call.sh /DATA /DATA/data/cramlist_local'
    call(remote_cmd + call_cmd, shell=True)
  else:
    #gui.remote = 'gppd1@143.54.48.77'
    #gui.hop = 'afarah@portal.inf.ufrgs.br'
    gui.remote = 'root@afarah.info'
    gui.hop = ''
    gui.ftp = ''
    gui.local = 'cramlist_local'
    gui.docker = 'afarah1/ubuntu-samtools'
    #gui.data = '/DATA'
    gui.data = '/mnt/volume_nyc3_01'
    gui.vcffilter = '--max-missing 0.5 --minDP 5 --min-alleles 2 --max-alleles 2 --minQ 20' # TODO actually use this

gui.run()
