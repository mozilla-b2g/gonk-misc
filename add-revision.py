#!/usr/bin/env python

# This simple script adds a rev attr to an android manifest file

import xml.dom.minidom
import subprocess
import sys
import os
from optparse import OptionParser

class MissingRepositoryException(Exception):
    pass

def cmd(args, cwd, bufsize=8192):
    """Execute a command based on the args and current
    working directory.  Read up to the first 8K of output
    and return the output as a strip()'d string"""
    #XXX This function sucks.
    proc = subprocess.Popen(args=args, cwd=cwd,
                            stdout=subprocess.PIPE,
                            stderr=subprocess.PIPE)
    output=proc.stdout.read(bufsize)
    proc.wait()
    return output.strip()

def git_op(args, path):
    """Call a command using some git specific logic, like
    checking whether the directory the command is to be run
    in exists.  Raises a MissingRepositoryException if the
    repository does not exist"""
    if not os.path.isdir(path):
        print >> sys.stderr, "%s (%s) was not found" % (path, os.path.abspath(path))
        raise MissingRepositoryException("Missing the %s repository" % path)
    return cmd(args, cwd=path)

def find_tag(path, only_annotated=False):
    """Given a path, use Git to figure out if there is a local
    or annotated tag for HEAD and return it as a string"""
    # Should verify that describe will only ever print the tag to stdout
    cmd = ['git', 'describe', '--exact-match']
    if not only_annotated:
        cmd.append('--tags')
    cmd.append('HEAD')
    p_tag = git_op(cmd, path=path)
    if len(p_tag) > 0:
        return p_tag
    else:
        return None

def find_rev(path):
    """Given a path, use Git to figure out what the commit id is
    for HEAD and return it as a string"""
    # Should verify that rev-parse will only ever print the rev to stdout
    return git_op(['git', 'rev-parse', 'HEAD'], path=path)

def find_ref(path, only_annotated=False):
    """Given a repository's path, return the newest tag for HEAD if the commit has
    been tagged, or the commit id if it hasn't"""
    tag=find_tag(path, only_annotated)
    rev=find_rev(path)
    if tag:
        return tag
    else:
        return rev

def add_revision(man_filename, b2g_root, output, force=False, tags=False, only_annotated=False):
    """Take a string that is a filename to the source manifest, the root
    of the repository tree and write a copy of the xml manifest to the file
    'output' that has revisions.  If tags is set to true, prepend each project
    node with a comment node that contains the name of the repository and the
    tag for that repository.  Specifying force=True will cause revisions in the
    original manifest to be overwritten with computed ones"""
    doc = xml.dom.minidom.parse(man_filename)
    for project in doc.getElementsByTagName("project"):
        if project.getAttribute('revision') and not force:
            pass
        else:
            manifest_path = project.getAttribute('path')
            fs_path = os.path.join(b2g_root, manifest_path)
            commit_id = find_rev(fs_path)
            project.setAttribute('revision', commit_id)
            parentNode = project.parentNode
            tag = find_ref(fs_path, only_annotated)
            if tags and tag != commit_id:
                comment = " Information: %s is tagged with %s " % (project.getAttribute('name'), tag)
                parentNode.insertBefore(doc.createComment(comment), project)
    if hasattr(output, 'write'):
        doc.writexml(output)
    else:
        with open(output, 'w+b') as of:
            doc.writexml(of)

def main():
    parser = OptionParser()
    parser.add_option("--b2g-path", dest="b2g_path",
                      help="path to root of the b2g repository tree",
                      default=os.getcwd())
    parser.add_option("--force", dest="force",
                      help="force changes to revision attributes",
                      action="store_true")
    parser.add_option("-o", "--output", dest="output",
                      help="output file to write new manifest to",
                      default=None)
    parser.add_option("--stdio", dest="stdio",
                      help="print new manifest to stdio instead of file",
                      action="store_true")
    parser.add_option("-t", "--tags", dest="tags",
                       help="attempt to resolve commit ids to tags",
                       action="store_true")
    parser.add_option("--only-annotated", dest="only_annotated",
                       help="only use annotated tags when resolving tags",
                       action="store_true")
    (options, args) = parser.parse_args()
    if options.output and options.stdio:
        parser.error("use one of --output, -o or --stdio")
    elif not options.output and not options.stdio:
        parser.error("must specify --output or --stdio")

    if not os.path.isdir(options.b2g_path):
        parser.error("b2g path is not a valid and existing directory")

    if len(args) != 1:
        parser.error("specify one manifest")

    add_revision(args[0],
                 options.b2g_path,
                 sys.stdout if options.stdio else options.output,
                 options.force,
                 options.tags,
                 only_annotated=options.only_annotated)

if __name__=="__main__":
    main()
