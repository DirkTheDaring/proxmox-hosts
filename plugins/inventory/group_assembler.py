from __future__ import absolute_import, division, print_function

__metaclass__ = type

# THIS IS NOT ONLY DOCUMENTATION!!!
# IT IS PARSED AND USED TO IMPORT DATA FROM THE MOUDLE!!!
DOCUMENTATION = """
    name: group_assembler
    version_added: "1.0"
    short_description: to be done
    description:
        - Uses a YAML configuration file with a valid YAML or C(.config) extension to define var expressions and group conditionals
    options:
        plugin:
            description: token that ensures this is a source file for the 'group_assembler' plugin.
            required: True
            choices: ['group_assembler']
        vargroups:
            description: Add hosts to group base on extra_vars
            type: dict
            default: {}
        groups:
            description: Add hosts to group based on Jinja2 conditionals.
            type: dict
            default: {}
        groups_match_prefix:
          description: tbd
          type: string
          default: ""
        groups_filter:
            description: Add hosts to group which match a pattern (fnmatch)
            type: dict
            default: {}
        ping_filter:
            description: Add hosts to group if they respond to ping
            type: dict
            default: {}

        use_extra_vars:
          version_added: '2.11'
          description: Merge extra vars into the available variables for composition (highest precedence).
          type: bool
          default: False
          ini:
            - section: inventory_plugins
              key: use_extra_vars
          env:
            - name: ANSIBLE_INVENTORY_USE_EXTRA_VARS
        use_vars_plugins:
            description:
                - Normally, for performance reasons, vars plugins get executed after the inventory sources complete the base inventory,
                  this option allows for getting vars related to hosts/groups from those plugins.
                - The host_group_vars (enabled by default) 'vars plugin' is the one responsible for reading host_vars/ and group_vars/ directories.
                - This will execute all vars plugins, even those that are not supposed to execute at the 'inventory' stage.
                  See vars plugins docs for details on 'stage'.
            required: false
            default: false
            type: boolean
            version_added: '2.11'

"""
import os

from ansible import constants as C
from ansible.errors import AnsibleParserError, AnsibleOptionsError
from ansible.inventory.helpers import get_group_vars
from ansible.plugins.inventory import BaseInventoryPlugin, Constructable
from ansible.module_utils._text import to_native
from ansible.utils.vars import combine_vars
from ansible.vars.fact_cache import FactCache
from ansible.vars.plugins import get_vars_from_inventory_sources
import fnmatch
import platform
import subprocess
from subprocess import Popen



class InventoryModule(BaseInventoryPlugin):
    """constructs groups with selectors"""

    NAME = "group_assembler"

    def __init__(self):
        super(InventoryModule, self).__init__()
        self.allow_extras = True
        self._cache = FactCache()

    def verify_file(self, path):
        valid = False
        if super(InventoryModule, self).verify_file(path):
            file_name, ext = os.path.splitext(path)
            if not ext or ext in [".config"] + C.YAML_FILENAME_EXTENSIONS:
                valid = True
        return valid

    def ping(self, host):
        """
        Returns True if host (str) responds to a ping request.
        Remember that a host may not respond to a ping (ICMP) request even if the host name is valid.
        """

        # Option for the number of packets as a function of
        param = '-n' if platform.system().lower()=='windows' else '-c'

        # Building the command. Ex: "ping -c 1 google.com"
        command = ['ping', param, '1', host]

        return subprocess.call(command) == 0

    def ping2(self, inventory, loader, sources, group):
        """
        Returns True if host responds to a ping request, if not blocked by firwewall
        """

        # Option for the number of packets as a function of
        param = '-n' if platform.system().lower()=='windows' else '-c'

        procs = []
        #print(group.host_names)
        for host_name in group.host_names:
            host_vars = self.get_all_host_vars(
                inventory.hosts[host_name], loader, sources
             )
            if 'ansible_host' in host_vars:
                target_host = host_vars['ansible_host']
            else:
                target_host = host_name
            command = ['ping', param, '2', target_host]
            proc = Popen(command, stdout=subprocess.DEVNULL, stderr=subprocess.STDOUT)
            procs.append([host_name,command,proc])

        result = []
        #print(procs)
        for item in procs:
           host_name, command, proc = item
           proc.wait()
           if proc.returncode == 0:
               result.append(host_name)
        #print(result)
        return result



    def get_all_host_vars(self, host, loader, sources):
        """requires host object"""
        return combine_vars(
            self.host_groupvars(host, loader, sources),
            self.host_vars(host, loader, sources),
        )

    def host_groupvars(self, host, loader, sources):
        """requires host object"""
        gvars = get_group_vars(host.get_groups())

        if self.get_option('use_vars_plugins'):
            gvars = combine_vars(gvars, get_vars_from_inventory_sources(loader, sources, host.get_groups(), 'all'))

        return gvars

    def host_vars(self, host, loader, sources):
        """requires host object"""
        hvars = host.get_vars()

        if self.get_option('use_vars_plugins'):
            hvars = combine_vars(hvars, get_vars_from_inventory_sources(loader, sources, [host], 'all'))

        return hvars

    def add(self, inventory, group_name, selectors):
        for selector in selectors:
            for host in inventory.hosts:
                if not fnmatch.fnmatch(host, selector):
                    continue
                group_name = self.inventory.add_group(group_name)
                self.inventory.add_child(group_name, host)


    def filter(self, inventory, loader, sources, host_names, matchExpressions):
        result = []
        for host_name in host_names:
            ok = False
            for matchExpression in matchExpressions:
                if "operator" not in matchExpression:
                    continue
                if "key" not in matchExpression:
                    continue

                key_name = matchExpression["key"]
                host_vars = self.get_all_host_vars(
                    inventory.hosts[host_name], loader, sources
                )

                if matchExpression["operator"] == "Exists":
                    if key_name not in host_vars:
                        ok = False
                        break
                    ok = True
                    continue

                if matchExpression["operator"] == "NotExists":
                    if key_name in host_vars:
                        ok = False
                        break
                    ok = True
                    continue

                if key_name not in host_vars:
                     continue
                key_value = host_vars[key_name]

                found = False
                for item in ["values", "values_from_group"]:
                   if item in matchExpression:
                       found = True
                       break
                if not found:
                    continue

                if "values" in matchExpression:
                   values = matchExpression["values"]
                elif "values_from_group" in matchExpression:
                   source_group_name = matchExpression["values_from_group"]
                   if source_group_name not in inventory.groups:
                       continue
                   source_group = inventory.groups[source_group_name]
                   values = source_group.host_names
                #print("key_value "+str(values))

                if matchExpression["operator"] == "In":
                    if key_value in values:
                        ok = True
                        continue
                    ok = False
                    break

                if matchExpression["operator"] == "NotIn":
                    if key_value not in values:
                        ok = True
                        continue
                    ok = False
                    break

                raise AnsibleParserError(
                    "failed to parse operator: %s, key: %s", matchExpression["operator"]
                )

            if ok:
                result.append(host_name)
        # print(result)
        return result

    def parse(self, inventory, loader, path, cache=False):
        # this sets self.inventory - so that we later can add groups + hoests
        super(InventoryModule, self).parse(inventory, loader, path, cache=cache)
        self._read_config_data(path)

        # This following line only works if the DOCUMENTATION has
        # defined this variable. Then the var self._options is set
        # automatically which in turn makes get_option work

        vargroups = self.get_option("vargroups")

        for group_name, var_name in vargroups.items():
            if var_name not in self._vars:
                continue
            selectors = [x.strip() for x in self._vars[var_name].split(",")]
            group_name = self._sanitize_group_name(group_name)
            self.add(inventory, group_name, selectors)

        groups_match_prefix = self.get_option("groups_match_prefix")
        if groups_match_prefix in self._vars:
            groups_match_prefix = self._vars[groups_match_prefix]

        groups = self.get_option("groups")
        for group_name, select_str in groups.items():
            selectors = [
                (groups_match_prefix + x.strip()) for x in select_str.split(",")
            ]
            # print(selectors)
            group_name = self._sanitize_group_name(group_name)
            self.add(inventory, group_name, selectors)

        sources = []
        try:
            sources = inventory.processed_sources
        except AttributeError:
            if self.get_option("use_vars_plugins"):
                raise AnsibleOptionsError(
                    "The option use_vars_plugins requires ansible >= 2.11."
                )

        groups = self.get_option("groups_filter")
        for group_name, params in groups.items():
            if "matchExpressions" not in params:
                continue
            matchExpressions = params["matchExpressions"]
            # print(type(matchExpressions))
            # if not isinstance(matchExpressions, List):
            #   continue
            if "group" not in params:
                continue
            source_group_name = params["group"]
            if source_group_name not in inventory.groups:
                continue
            source_group = inventory.groups[source_group_name]

            result = self.filter(
                inventory, loader, sources, source_group.host_names, matchExpressions
            )
            #print("host_names = " + str(source_group.host_names))
            #print("result = " + str(result))
            group_name = self._sanitize_group_name(group_name)
            group_name = self.inventory.add_group(group_name)
            for host in result:
                self.inventory.add_child(group_name, host)

        groups = self.get_option("ping_filter")
        for group_name, params in groups.items():
            if "group" not in params:
                source_group_name = "all"
            else:
                source_group_name = params["group"]

            if source_group_name not in inventory.groups:
                continue

            source_group = inventory.groups[source_group_name]
            #print("source_group_name = " + str(source_group_name))
            #print("source_group = " + str(source_group.host_names))

            group_name = self._sanitize_group_name(group_name)
            group_name = self.inventory.add_group(group_name)
            result = self.ping2(inventory, loader, sources, source_group)
            for host_name in result:
                self.inventory.add_child(group_name, host_name)

            # we might want to keep the old ping method for a larger
            # batch of hosts, or modify the parallel execution to
            # a process limit it can do
            #
            #for host_name in source_group.host_names:
            #    if not self.ping(host_name):
            #        continue
            #    self.inventory.add_child(group_name, host_name)
