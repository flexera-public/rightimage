#!/usr/bin/python
#
# Copyright (c) 2010 Red Hat, Inc.
#
# This software is licensed to you under the GNU General Public License,
# version 2 (GPLv2). There is NO WARRANTY for this software, express or
# implied, including the implied warranties of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. You should have received a copy of GPLv2
# along with this software; if not, see
# http://www.gnu.org/licenses/old-licenses/gpl-2.0.txt.
#
# Red Hat trademarks are not licensed under GPLv2. No permission is
# granted to use or replicate Red Hat trademarks that are incorporated
# in this software or its documentation.

import base64
import urllib

from yum.plugins import TYPE_CORE


requires_api_version = '2.3'
plugin_type = (TYPE_CORE,)


def init_hook(conduit):
    '''
    Plugin initialization hook. For each RHUI repo, replace yum's representation of the
    repo with a subclass that adds in the necessary headers.
    '''

    # Only process RHUI repos
    repos = conduit.getRepos()
    rhui_repos = repos.findRepos('rhui-*')

    # Retrieve the Amazon metadata
    id_doc = _load_id()
    signature = _load_signature()

    # Encode it so it can be inserted as an HTTP header
    id_doc = base64.urlsafe_b64encode(id_doc)
    signature = base64.urlsafe_b64encode(signature)

    # Add the headers to all RHUI repos
    for repo in rhui_repos:
        repo.http_headers['RHUI-Id'] = id_doc
        repo.http_headers['RHUI-Signature'] = signature

def _load_id():
    '''
    Loads and returns the Amazon metadata for identifying the instance.

    @rtype: string
    '''
    fp = urllib.urlopen('http://169.254.169.254/latest/dynamic/instance-identity/document')
    id_doc = fp.read()
    fp.close()

    return id_doc

def _load_signature():
    '''
    Loads and returns the signature of hte Amazon identification metadata.

    @rtype: string
    '''
    fp = urllib.urlopen('http://169.254.169.254/latest/dynamic/instance-identity/signature')
    id_doc = fp.read()
    fp.close()

    return id_doc
