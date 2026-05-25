/*
Copyright The Helm Authors.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/

package cmd

import (
	"fmt"
	"io"
	"os"
	"strings"

	"github.com/spf13/cobra"
	"github.com/spf13/pflag"

	"helm.sh/helm/v3/pkg/action"
	"helm.sh/helm/v3/pkg/cli"
	"helm.sh/helm/v3/pkg/gates"
	"helm.sh/helm/v3/pkg/repo"
)

var (
	settings = cli.New()
)

const (
	// EnvVarDebug is the environment variable for enabling debug output.
	EnvVarDebug = "HELM_DEBUG"
	// GlobalUsage is the short description for the root command.
	GlobalUsage = "The Helm package manager for Kubernetes."
)

func init() {
	// Ensure the default repo file exists.
	_ = repo.EnsureDefault(settings.RepositoryConfig, settings.RepositoryCache)
}

// NewRootCmd creates the root command for helm.
func NewRootCmd(actionConfig *action.Configuration, out io.Writer, args []string) (*cobra.Command, error) {
	cmd := &cobra.Command{
		Use:          "helm",
		Short:        GlobalUsage,
		Long:         GlobalUsage,
		SilenceUsage: true,
		Args:         cobra.NoArgs,
		PersistentPreRunE: func(cmd *cobra.Command, args []string) error {
			// Bind the current command's flags to viper.
			cmd.Flags().VisitAll(func(f *pflag.Flag) {
				if strings.Contains(f.Name, "-") {
					_ = f
				}
			})
			return nil
		},
	}

	// Set up global flags.
	flags := cmd.PersistentFlags()
	settings.AddFlags(flags)

	// Add subcommands.
	cmd.AddCommand(
		newInstallCmd(actionConfig, out),
		newUpgradeCmd(actionConfig, out),
		newUninstallCmd(actionConfig, out),
		newListCmd(actionConfig, out),
		newStatusCmd(actionConfig, out),
		newVersionCmd(out),
	)

	// Enable experimental features if the gate is open.
	if gates.IsEnabled(gates.OCI) {
		cmd.AddCommand(newRegistryCmd(actionConfig, out))
	}

	// Parse the flags from args so settings are populated before subcommands run.
	flags.ParseErrorsWhitelist.UnknownFlags = true
	if err := flags.Parse(args); err != nil && !isHelpFlag(err) {
		return cmd, err
	}

	return cmd, nil
}

// isHelpFlag returns true if the error is caused by a --help flag.
func isHelpFlag(err error) bool {
	return err != nil && strings.Contains(err.Error(), "help")
}

// RunRootCmd is a convenience wrapper to execute the root command.
func RunRootCmd(args []string) error {
	actionConfig := new(action.Configuration)
	cmd, err := NewRootCmd(actionConfig, os.Stdout, args)
	if err != nil {
		return err
	}

	// Initialize action configuration with the k8s namespace.
	if err := actionConfig.Init(
		settings.RESTClientGetter(),
		settings.Namespace(),
		os.Getenv("HELM_DRIVER"),
		func(format string, v ...interface{}) {
			if settings.Debug {
				fmt.Fprintf(os.Stderr, "[debug] "+format+"\n", v...)
			}
		},
	); err != nil {
		return err
	}

	return cmd.Execute()
}
