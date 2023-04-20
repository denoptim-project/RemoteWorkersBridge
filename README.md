# Submit Jobs To Remote Workers
This is a simple interface that creates a bridge between a local client and one or more remore clients (i.e., the "workers"), and uses such bridge to send computational tasks (i.e., jobs) to those remote clients, a.k.a. workers. The workers are typically high-performance cumputing (HPC) clusters where jobs can be submitted to a scheduler or a queuing system. 

The nature of the scheduler/queue is not influencing the present repository because the purpose of this repository is to collect tools and documentation that allows to configure a secure connection, trasfer files from/to a local client to/from the remote worker, send jobs to the remote worker, wait for completion of the job, and retrieve the results.
Still, we here ***assume the existence of commands to submit jobs to the queue*** (see submission commands in the **runners** scripts you find undder the [runners](runners) folder). Custom job submission commands can be easily integrated by adding the corresponding script in the [runners](runners) folder, and by adding another case of permitted command in the [commandFilter.sh](commandFilter.sh). 

## How to setup a "sub-to-remote bridge"
<ol>
<li> Clone the repository to your local client.</li>
<li> Clone the repository to each HPC worker you want to submit to.</li>
<li> Create a ssh key pair for connecting safely to the remote HPC workers. 
<pre>
ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa_HPCWorkers
</pre>
It is highly recommended to choose any non-empty passphrase and to use any agent enabling password-less authentication. For example, to use the simple <a href="https://www.ssh.com/academy/ssh/agent">ssh-agent</a> just do this:
<pre>
eval `ssh-agent -s`
ssh-add ~/.ssh/id_rsa_HPCWorkers
</pre>
and give the passphrase you have chosen in the previous step. The ssh-agent is session-specific, meaning that it survives as long as your session is active (this, uless you kill it, or is killed by some sort of problem). Therefore, the <code>ssh-add</code> command has to be repeated for every new session on your local client. For example, when after reboot or log-out/log-in.</li>

<li> Copy the identity/key to each remote HPC worker with this command:
<pre>
ssh-copy-id -i ~/.ssh/id_rsa_HPCWorkers your_username@your_worker_IP
</pre>
where <code>your_username</code> and <code>your_worker_IP</code> should be replaced with your specific username and IP address.</li>

<li> For each remote HPC worker, log in to <code>your_worker_IP</code> and edit the <code>~/.ssh/authorized_keys</code> file. The last line of this file should contain the ssh key entry you have just added with the ssh-copy-id command above. We are now going to edit this line to prevent any misuse of this automated login channel. This is done by limiting the usage to this key enabling only a privately own command filter. To this end, edit the line pertaining the ssh key we just authorized (i.e., the last line of <code>~/.ssh/authorized_keys</code> ), and pre-pend (i.e., add in front of any text of that line) the following string:
<pre>
from="your_IP",command="your_path_to/RemoteWorkersBridge/commandFilter.sh" 
</pre>
where <code>your_IP</code> is the IP address of your local client (the machine what will use this connection to submit jobs to the worker) and <code>your_path_to</code> is the path to the clone of this repository on the HPC worker.</li>

<li>Specify the configurations constrolling the functionality of the bridge between the local client and the HPC workers. This is done by creating a <code>configuration</code> file. These details ***MUST*** be specified in a file named `configuration`. Your <code>configuration</code> file must be place beside the [configuration.example](configuration.example) file, i.e., in your local copies of this repository both on the local client and on the remote HPC worker (the repositories you have clone in steps 1. and 2.). The settings of the repository (i.e., the `.gitignore` file) are so that the `configuration` file is not tracked by git.
An example of such file is available in [configuration.example](configuration.example). The configuration needed to use these scripts includes:
<ul>
<li> identity of the workers (plus details of what a worker is capable of)</li>
<li> ssh identity definitions (i.e., usernames and pathname to private ssh keys)</li>
<li> pathnames defining where to place files related to jobs</li>
</ul></li>

<li>At this point you should be ready to use the "subnit-to-remote" bridge. This is how to quicky run a test:
<pre>
cd submit_tool/test/
./runTest.sh
</pre>
After some seconds the result should be a conforting message saying that the test was successfully passed. Now you are ready to use the bridge to send calculations to the remote worker.</li>
</ol>

# Troubleshoot
* <b>Ensure usage of the right ssh key</b>. If you already have other ssh keys authorized for a worker, you must make sure that the right identity is used when connecting with the scripts from this repository. Try commenting out (removing authorization) the other lines in the worker's ~/.ssh/authorized_keys to verify you are indeed using the expected key. 
* <b>"Command not found" when submitting tasks</b> This is a problem easy to reproduce by running the `runTest.sh` under [submit_tool/test](submit_tool/test). It is usually the result of having multiple authorized keys from the local client to the worker, and not having a properly functioning key that calls via the `commandFilter.sh` script on the worker. In more detail, when you use a non-empty passphrase AND rely on ssh-agent to manage the passphrases AND you reboot your local client, you might forget to do `ssh-add` to enable password-less login using the proper identity file. This means the intended ssh key will not be authorized and other ssh keys will be tried. However, since these other authorized keys do not require execution of the `commandFilter.sh` script on the worker, the submission commands are not understood by the worker and you end up with the `command not found`.
