# k8s-tiller-history-cleanup

Kubernetes Tiller/Helm Release History Cleanup, a script to cleanup old helm tiller history config maps.

See also: https://www.kaper.com/cloud/k8s-tiller-helm-history-cleanup/

This can be handy if you forgot to set TILLER_HISTORY_MAX on your tiller deployment, and added it later on.
Or... if you remove components using kubectl delete instead of using helm delete (we do remove some namespaces
automatically, which leaves unused tiller configmaps in the system).

In the script, change the two variables below to match your setup.
```
TILLER_NAMESPACE=kube-system
TILLER_HISTORY_MAX=5
```

In our cluster, I used the following command to alter the history size:
```
kubectl edit deploy -n kube-system tiller-deploy
```

This is the env fragment:
```
      - env:
        - name: TILLER_NAMESPACE
          value: kube-system
        - name: TILLER_HISTORY_MAX
          value: "5"
```

The script can be called using: ./tiller-cleanup.sh with a single parameter of -f or -n:
```
Usage: ./tiller-cleanup.sh [-f | -n]
Use -n for a dry-run to show what would be deleted
Use -f to execute a run with actual deletes
```

Note: the script also queries the system for ALL components which are labeled with heritage=Tiller,
to find if there is an active helm deploy for a certain release. If not found, the helm history
will be removed.

Please be carefull, and first execute a dry-run to see if the script will remove the right
data for your setup.

Note: this script needs a working kubectl command, with active Kubernetes cluster context. It does not need helm.

For reference, the versions of helm/k8s on which we use this:
```
$ helm version
Client: &version.Version{SemVer:"v2.8.2", GitCommit:"a80231648a1473929271764b920a8e346f6de844", GitTreeState:"clean"}
Server: &version.Version{SemVer:"v2.8.2", GitCommit:"a80231648a1473929271764b920a8e346f6de844", GitTreeState:"clean"}

$ kubectl version
Client Version: version.Info{Major:"1", Minor:"8", GitVersion:"v1.8.5", GitCommit:"cce11c6a185279d037023e02ac5249e14daa22bf", GitTreeState:"clean", BuildDate:"2017-12-07T16:16:03Z", GoVersion:"go1.8.3", Compiler:"gc", Platform:"linux/amd64"}
Server Version: version.Info{Major:"1", Minor:"8", GitVersion:"v1.8.1+coreos.0", GitCommit:"59359d9fdce74738ac9a672d2f31e9a346c5cece", GitTreeState:"clean", BuildDate:"2017-10-12T21:53:13Z", GoVersion:"go1.8.3", Compiler:"gc", Platform:"linux/amd64"}
```


28/5/2019, Thijs Kaper.

# Open Issue:

  * https://github.com/atkaper/k8s-tiller-history-cleanup/issues/2 - a helm chart containing only some configmap or secret loses it's history.

24/7/2020.

