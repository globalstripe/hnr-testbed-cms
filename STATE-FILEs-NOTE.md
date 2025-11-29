
Where are my state files ?

By defailt the are stored locall in .pulumi

From the root try

find .pulumi/apps

You should see the state files for each environment and application 

.
├── apps
│   ├── core
│   │   ├── .pulumi
│   │   │   ├── backups
│   │   │   ├── history
│   │   │   └── stacks
│   ├── api
│   │   ├── .pulumi
│   │   │   ├── backups
│   │   │   ├── history
│   │   │   └── stacks
│   ├── admin
│   │   ├── .pulumi
│   │   │   ├── backups
│   │   │   ├── history
│   │   │   └── stacks
│   └── website
│       ├── .pulumi
│       │   ├── backups
│       │   ├── history
│       │   └── stacks
│  
└── (...)

This is the default backend, with which, all of the state files are stored within your Webiny project, inside of a single .pulumi folder, located in your project root.

Note that this folder contains cloud infrastructure state files for all project applications you might have in your Webiny project.

You probably dont want this for your production deployment.

You can use an S3 Bucket to store state - or you can use the Pulumi Service

https://www.webiny.com/docs/core-development-concepts/ci-cd/cloud-infrastructure-state-files


