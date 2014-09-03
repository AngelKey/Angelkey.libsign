
libkb = require 'libkeybase'
{User} = libkb

# Your app needs to provide some idea of local storage that meets our requirements.
{LocalStore} = require 'myapp'

# Open the LocalStore, which can create one if none existed beforehand.
await LocalStore.open defer err, store

# Steps to loading a user:
#
#   1. Fetching all signature data from the server (or from local storage)
#   2. Cryptographic Checks
#       a. Checking the tail of the sigchain is in the Merkle Tree.
#       b. Checking the merkle tree is in the blockchain (optional)
#       c. Checking all links of the signature chain point to each other.
#       d. Checking that the tail is signed by the most recent active public key (the user might have
#          switched halfway down the chain).
#   3. Identity Table Construction - Flatten the signature chain into a final "identity table"
#      of remote identities that link to this username/key combination.
#
# Next, 4a, b, and c can happen in any order:
#
#   4a. Remote check --- check that all proofs in the identity table still exist
#   4b. Tracking resolution --- check the computed identity table against any existing tracker statements,
#       and resolve what needs to be fixed to bring any stale tracking up-to-date
#   4c. Assertions -- check the user's given assertions against the computed identity table
#
# Next, 5 can happen only after all of 4a, b, and c
#
#   5. track/retrack -- sign a new tracking statement, if necessary, signing off on the above computations.
#

# Load a user from the server, and perform steps 1, 2, and 3.  Recall that step 2b is optional,
# and you can provide options here to enable it.  If you do provide that option, there might be a
# latency of up to 6 hours.
#
# The Store is optional, but if provided, we can check the store rather than
# fetch from the server.
await User.load { store, query : { keybase : "max" }, opts : {} }, defer err, me

# As in 4c above...
await me.assert { assertions : [ { key : "aabbccdd" }, { "reddit" : "maxtaco" }, { "web" : "https://goobar.com" } ] }, defer err

# Load a second user...
await User.load { store, query : { "twitter" : "malgorithms" } }, defer err, chris

# As in 4b above...
#
# State can be: NONE, if I haven't tracked Chris before; OK if my tracking
# statement is fully up-to-date, STALE if my tracking statement is out-of-date,
# or SUBSET, if it's a proper subset of the current state.
#
await chris.check_tracking { tracker : me }, defer err, state

# As in 4a above.
#
# An error will be returned if there was a catastrophic failure, not if
# any one of the proofs failed. Check the status field for OK if all succeded, or
# PARTIAL_FAILURE if some failed.
#
# Note that there is a 1-to-1 correspondence between the IdentityTable object and the
# User object, but they are split apart for convenience.
#
idtab = chris.get_identity_table()
await idtab.check_remotes {}, defer err, status

# As in 4c, optional assertions against the identity table
await idtab.assert { assertions : [ { "key" : "aabb" }, { "reddit" : "maxtaco" } ] }, defer err

# Outputs any failures in JSON format, though you can query the idtab in a number of different ways
# (which aren't finalized yet...)
failures = idtab.get_failures_to_json()

# Fetch a key manager for a particular app (or for the main app if none specified), and for
# the given public key operations.
await chris.fetch_key_manager { { app : "myencryptor" }, ops }, defer err, km