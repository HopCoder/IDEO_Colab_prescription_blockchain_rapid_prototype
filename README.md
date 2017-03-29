# Project

This is a rapid prototype meant to demonstrate a possible workflow of
prescribing medications from a provider standpoint and filling them from a
pharmacy standpoint using blockchains for the data flow.  You should be able to
demo this simply through a command line interface prompt by running the
contained code.

See lib/project.rb and the comment block at the top for more info.

## Usage

Setup and run <a href='https://chain.com'>Chain Core</a>, then you can show the
provider workflow:

    $ ruby lib/project.rb
    provider

And the pharmacy workflow.  You'll want to run these concurrently.

    $ ruby lib/project.rb
    pharmacy

Once both of these are running, follow the prompts

