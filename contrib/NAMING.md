# Naming in contributions: useful, not identifying

Everything under `contrib/` is public. It describes **what kind of setup** produced a result, never **which** setup. A reader should learn "a remote consumer reaching a 12 GB NVIDIA card in a container over a direct path", never a machine name, address, person, or network.

## Never in a contribution

- machine, VM, container, or tailnet names, including nicknames and aliases;
- IP addresses, MAC addresses, ports tied to a specific host, domain names, URLs;
- user names, people's names, email addresses, organization names;
- file paths, key fragments, fingerprints, session ids, prompts, responses, conversation text;
- exact timestamps (use the `month` field), exact purchase or balance figures.

## Use these descriptors instead

| Thing | Descriptor | Example |
|---|---|---|
| A contribution file | its name: **fresh** 8 random hex per file, never the `contributor_id` | `9c41e0b2.yaml` |
| The contributing box | `contributor_id`: 8 random hex, generated **once at install** and stored in `state/switcher-adoption.yaml`. Never derived from a hostname or key. | `3f9a1c07` |
| The box's role | `consumer`, `gpu_host`, `consumer_and_gpu_host` | `consumer` |
| A lane | `lane-a`, `lane-b`, …, assigned in a fixed order per box and kept stable across that box's reports | `lane-b` |
| What the lane is | `role`: `local_gpu`, `local_cpu`, `peer_gpu`, `peer_cpu`, `relayed_peer_gpu`, `api` | `relayed_peer_gpu` |
| Its hardware | `gpu`: vendor + memory band (`nvidia-8-16GB`, `intel-8-16GB`, `none`). Use the card's **actual** memory: a 12 GB card is `8-16GB`, a 16 GB card is `8-16GB`, an 8 GB card is `<=8GB`. | `intel-8-16GB` |
| How it's hosted | `virtualization`: `bare_metal`, `vm`, `container` | `container` |
| How it's reached | `path`: `same_box`, `same_host`, `lan`, `remote_direct`, `remote_relayed` | `remote_relayed` |
| Box size | bands: `cpu_cores` `17-32`, `ram_gb` `65-128`, `gpu_class` `8-16GB` | |
| Providers and models | public provider names and public catalog model ids are fine (`openrouter`, `deepseek/deepseek-v4-flash`). A **local custom tag** that embeds a machine or person name is not: describe it as its base model. | `qwen3-30b-a3b` |

In free text (`observed`, `how_to_reproduce`, `why_it_matters`, `evidence`, `proposal`), use the same words: "the GPU host", "the consumer box", "lane-b (a relayed peer GPU)".

## The deny list (box-local, never committed)

Each box keeps `state/contrib-deny.txt`: one term per line, built from its own names and aliases, the names of its lanes and peers, addresses, tailnet domain, user names, and home paths. It is regenerated at every submission. `checks/contrib-validate.py --deny-file state/contrib-deny.txt <file>` rejects any contribution containing one of those terms, in any field, in any case. The generic checks catch addresses, URLs, emails, paths and key-like strings everywhere; the deny list catches the names only the box knows.

## Why not just hash the names?

A hash of a short name is easy to reverse with a guess list, and the same hash across reports links them to the name forever. A random `contributor_id` and stable `lane-a/b/c` letters link a box's own reports over time, for trend analysis, without revealing anything.
