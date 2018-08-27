#!/usr/bin/env nix-shell
#! nix-shell -i python3 -p python3 python3.pkgs.click

from urllib.request import Request, urlopen, urlretrieve
import json
import os.path
import click

def download_file(hydra, build, target=".", name=None, product="1"):
    origname = build["buildproducts"][product]["name"]
    fname = name if name is not None else origname
    urlretrieve("{}/build/{}/download/{}/{}".format(
        hydra, build["id"], product, origname
    ), os.path.join(target, fname))

def fetch_json(url):
    req = urlopen(Request(url, headers = { "Accept": "application/json" }))
    return json.load(req)

@click.command()
@click.option("--hydra", default="http://localhost:3000")
@click.option("--project", default="holoportOS")
@click.option("--jobset", default="master")
@click.option("--target", default=".")
def release(hydra, project, jobset, target):
    testedInfo = fetch_json("{}/job/{}/{}/tested/latest-finished".format(hydra, project, jobset))
    latestEval = sorted(testedInfo["jobsetevals"])[-1]
    evalInfo = fetch_json("{}/eval/{}".format(hydra, latestEval))

    builds = [fetch_json("{}/build/{}".format(hydra, build)) for build in evalInfo["builds"]]
    jobs = dict((build["job"], build) for build in builds)

    targetDir = os.path.join(target, "{}-{}".format(jobset, latestEval))
    try:
        os.mkdir(targetDir)
    except FileExistsError:
        exit(0)

    print("Releasing {}:{}".format(project, targetDir))

    download_file(hydra, jobs["channels.nixpkgs"], target=targetDir, name="nixexprs-nixpkgs.tar.xz")
    download_file(hydra, jobs["channels.holoport"], target=targetDir, name="nixexprs-holoport.tar.xz")
    download_file(hydra, jobs["iso"], target=targetDir, name="holoportos.iso")

    targetLink = os.path.join(target, jobset)
    os.symlink(targetDir, targetLink + ".new")
    os.rename(targetLink + ".new", targetLink)

if __name__ == "__main__":
    release()
