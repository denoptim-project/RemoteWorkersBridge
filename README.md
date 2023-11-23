# Submit Jobs To Remote Workers
This is a simple interface that creates a bridge between a local client and one or more remote clients (i.e., the "workers"), and uses such bridge to send computational tasks (i.e., jobs) to those remote clients, a.k.a. workers. The workers are typically high-performance computing (HPC) clusters where jobs can be submitted to a scheduler or a queuing system. 

The nature of the scheduler/queue is not influencing the present repository because the purpose of this repository is to collect tools and documentation that allows to configure a secure connection, transfer files from/to a local client to/from the remote worker, send jobs to the remote worker, wait for completion of the job, and retrieve the results.
Still, we here ***assume the existence of commands to submit jobs to the queue*** (see submission commands in the **runners** scripts you find under the [runners](runners) folder). Custom job submission commands can be easily integrated by adding the corresponding script in the [runners](runners) folder, and by adding another case of permitted command in the [commandFilter.sh](commandFilter.sh). 

## How to setup a "sub-to-remote bridge"
1. Clone/copy the repository to your local client.
2. Clone/copy the repository to each HPC worker you want to submit to.
3. On each HPC worker set the permission mask on the command filter. Use the following command, but replace the string `path_to_your_copy_of_this_repository_on_the_HPC_worker` with the path that: applies to your specific file system:
    ```
    cd path_to_your_copy_of_this_repository_on_the_HPC_worker/RemoteWorkersBridge
    chmod 700 commandFilter.sh
    ```
4. Create a ssh key pair for connecting safely to the remote HPC workers. 
    ```
    ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa_HPCWorkers
    ```
    It is highly recommended to choose any non-empty passphrase and to use any agent enabling password-less authentication. For example, to use the simple <a href="https://www.ssh.com/academy/ssh/agent">ssh-agent</a> just do this:
    ```
    eval `ssh-agent -s`
    ssh-add ~/.ssh/id_rsa_HPCWorkers
    ```
    and give the passphrase you have chosen in the previous step. The ssh-agent is session-specific, meaning that it survives as long as your session is active (this, unless you kill it, or is killed by some sort of problem). Therefore, the `ssh-add` command has to be repeated for every new session on your local client. For example, when after reboot or log-out/log-in.

5. Copy the identity/key to each remote HPC worker with this command:
    ```
    ssh-copy-id -i ~/.ssh/id_rsa_HPCWorkers your_username@your_worker_IP
    ```
    where `your_username` and `your_worker_IP` should be replaced with your specific user-name and IP address.

6. For each remote HPC worker, log in to `your_worker_IP` and edit the `~/.ssh/authorized_keys` file. The last line of this file should contain the ssh key entry you have just added with the ssh-copy-id command above. We are now going to edit this line to prevent any misuse of this automated login channel. This is done by limiting the usage to this key enabling only a privately own command filter. To this end, edit the line pertaining the ssh key we just authorized (i.e., the last line of `~/.ssh/authorized_keys`), and pre-pend (i.e., add in front of any text of that line) the following string (NB: there is a space at the end!):
    ```
    from="your_IP",command="path_to_your_copy_of_this_repository_on_the_HPC_worker/RemoteWorkersBridge/commandFilter.sh" 
    ```
    where `your_IP` is the IP address of your local client (the machine what will use this connection to submit jobs to the worker) and `path_to_your_copy_of_this_repository_on_the_HPC_worker` is the path to the RemoteWorkersBridge folder on the HPC worker: the same you have used above.

7. Specify the configurations controlling the functionality of the bridge between the local client and the HPC workers. This is done by creating a `configuration` file. These details ***MUST*** be specified in a file named `configuration`. Your `configuration` file must be place beside the [configuration.example](configuration.example) file, i.e., in your local copies of this repository both on the local client and on the remote HPC worker (the repositories you have clone in steps 1. and 2.). The settings of the repository (i.e., the `.gitignore` file) are so that the `configuration` file is not tracked by git.
    An example of such file is available in [configuration.example](configuration.example). The configuration needed to use these scripts includes:

    * `remoteIP` is the identity of the HPC worker in the network</li>
    * `wdirOnRemote` a pathname defining the work directory on the HPC worker. Your remote client will send any files defining a job (e.g., input files) on this location of the HPC worker, and from there the HPC worker will take any such files for any further processing, e.g., for submit a job defined by those input files.
    * `userOnRemote` your used name on the HPC worker. This is used to send files and requests to the HPC worker via `scp`.
    * `identityFile` the pathname to the file containing the private part of the ssh key you have created in the above procedure (NB: this pathname is the one that **does NOT end with ~~.pub~~**).
    * `workKind` defined what kind of work a specific worker is able to do. This allows to register multiple HPC workers and use each of them for specific tasks that are best suited for their architecture.

8. Copy the `configuration` file from your local client to each of the HPC workers. It must be place beside the [configuration.example](configuration.example) file present in the copy of this repository on each HPC worker (the repositories you have clone in step 2.).

9. Done! You should now be ready to use the bridge to the remote HPC workers. This is how to quickly run a test:
    ```
    cd submit_tool/test/
    ./runTest.sh
    ```
    After some seconds the result should be a comforting message saying that the test was successfully passed. Now you are ready to use the bridge to send calculations to the remote worker.


# Troubleshoot
* <b>Ensure usage of the right ssh key</b>. If you already have other ssh keys authorized for a worker, you must make sure that the right identity is used when connecting with the scripts from this repository. Try commenting out (removing authorization) the other lines in the worker's ~/.ssh/authorized_keys to verify you are indeed using the expected key. 
* <b>"Command not found" when submitting tasks</b> This is a problem easy to reproduce by running the `runTest.sh` under [submit_tool/test](submit_tool/test). It is usually the result of having multiple authorized keys from the local client to the worker, and not having a properly functioning key that calls via the `commandFilter.sh` script on the worker. In more detail, when you use a non-empty passphrase AND rely on ssh-agent to manage the passphrases AND you reboot your local client, you might forget to do `ssh-add` to enable password-less login using the proper identity file. This means the intended ssh key will not be authorized and other ssh keys will be tried. However, since these other authorized keys do not require execution of the `commandFilter.sh` script on the worker, the submission commands are not understood by the worker and you end up with the `command not found`.
* When testing and debugging with `submit_tool/test/runTest.sh` make sure there are no other authentication keys between local and remote worker. Otherwise you may be performing ssh with a different authorized key from the one that is forced to run the command filter.
* 
