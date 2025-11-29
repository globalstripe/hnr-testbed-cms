import cliWorkspaces from "@webiny/cli-plugin-workspaces";
import cliPulumiDeploy from "@webiny/cli-plugin-deploy-pulumi";
import cliAwsTemplate from "@webiny/cwp-template-aws/cli";
import cliExtensions from "@webiny/cli-plugin-extensions";

// Scaffolds.
import cliScaffold from "@webiny/cli-plugin-scaffold";
import cliScaffoldExtendGraphQlApi from "@webiny/cli-plugin-scaffold-graphql-service";
import cliScaffoldAdminModule from "@webiny/cli-plugin-scaffold-admin-app-module";
import cliScaffoldExtensions from "@webiny/cli-plugin-scaffold-extensions";
import cliScaffoldWorkspaces from "@webiny/cli-plugin-scaffold-workspaces";
import cliScaffoldCiCd from "@webiny/cli-plugin-scaffold-ci";

export default {
    id: "humansnotrobots/clearshore",
    template: "@webiny/cwp-template-aws@5.43.5",
    name: "hnr-testbed",
    cli: {
        plugins: [
            cliWorkspaces(),
            cliPulumiDeploy(),
            cliAwsTemplate(),
            cliExtensions(),

            // Scaffolds.
            cliScaffold(),
            cliScaffoldExtendGraphQlApi(),
            cliScaffoldAdminModule(),
            cliScaffoldExtensions(),
            cliScaffoldWorkspaces(),
            cliScaffoldCiCd()
        ]
    },
    appAliases: {
        blueGreen: "apps/blueGreen",
        core: "apps/core",
        api: "apps/api",
        admin: "apps/admin",
        website: "apps/website"
    }
};
