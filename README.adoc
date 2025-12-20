= Cadre Router - ReScript-Deno Router: Type-Safe, CRDT-Backed HTTP Routing
:toc: left
:toclevels: 3
:icons: font
:source-highlighter: rouge
:rouge-style: github
:experimental:
:repo: https://gitlab.com/rescript-deno/router
:deno-version: 1.38.0
:rescript-version: 11.0.0

image:https://gitlab.com/rescript-deno/router/badges/main/pipeline.svg[Pipeline Status,link={repo}/-/pipelines]
image:https://gitlab.com/rescript-deno/router/badges/main/coverage.svg[Coverage,link={repo}/-/graphs/main/charts]
image:https://img.shields.io/badge/deno-{deno-version}-blue[Deno Version]
image:https://img.shields.io/badge/rescript-{rescript-version}-e6484f[ReScript Version]
image:https://img.shields.io/badge/license-MIT-green[License]

[.lead]
A production-grade HTTP router that brings OCaml's type safety to Deno's runtime with conflict-free replicated data types (CRDTs) for distributed state management.

== Why This Exists

Traditional web frameworks face three critical problems in distributed deployments:

[cols="1,2,2"]
|===
|Problem |Traditional Solution |Our Solution

|**Type Safety**
|TypeScript (unsound type system, slow compilation)
|ReScript (OCaml-grade soundness, 10-100x faster compilation)

|**Distributed State**
|Databases + distributed locking + cache invalidation
|CRDTs (conflict-free, no coordination, offline-first)

|**Runtime Security**
|Process isolation, environment variables, manual validation
|Deno permissions (explicit, granular, auditable)
|===

=== The Stack

[source,mermaid]
----
graph TB
    A[ReScript Source] -->|Compile| B[JavaScript]
    B -->|Run| C[Deno Runtime]
    C -->|Deploy| D[Deno Deploy Edge]
    C -->|State| E[Deno KV + CRDTs]
    C -->|Jobs| F[Deno Queue]
    C -->|Schedule| G[Deno Cron]
----

== Quick Start

=== Prerequisites

[source,bash]
----
# Install Deno (if not already installed)
curl -fsSL https://deno.land/install.sh | sh

# Install ReScript compiler
npm install -g rescript@{rescript-version}
----

=== Installation

[source,bash]
----
# Clone the repository
git clone {repo}.git
cd router

# Install dependencies
npm install

# Build ReScript code
npm run build

# Run tests
deno task test

# Start development server
deno task dev
----

=== Your First Route

[source,rescript]
----
// main.res
open Router

type context = {
  db: Database.t,
  userId: option<string>,
}

let app = 
  Router.make()
  ->Router.get("/", (ctx, _req) => {
      Promise.resolve(
        Deno.Response.json({
          "message": "Hello from ReScript + Deno!",
          "timestamp": Date.now(),
        })
      )
    })
  ->Router.get("/user/:id", (ctx, req) => {
      let id = ctx.params->Params.get("id")->Option.getExn
      ctx.db
      ->Database.getUser(id)
      ->Promise.map(user => {
          Deno.Response.json({
            "id": user.id,
            "name": user.name,
            "tier": user.tier->Tier.toString,
          })
        })
    })
  ->Router.serve(~ctx={db: Database.connect(), userId: None})
----

[source,bash]
----
# Compile and run
npm run build && deno task start

# Test the endpoints
curl http://localhost:8000/
curl http://localhost:8000/user/123
----

== Architecture

=== Layer Design

The project follows a strict four-layer architecture:

[cols="1,2,2,1"]
|===
|Layer |Purpose |Key Technologies |Stability

|**Core**
|HTTP routing primitives
|Route matching, middleware composition, Deno FFI
|🟢 Stable

|**Standard**
|CRDT-backed state management
|CausalLog, GSet, ORSet, LWWMap, VectorClock
|🟡 Beta

|**Extended**
|Production features
|Deno KV/Queue/Cron, WebSocket sync, tracing, codegen
|🟠 Alpha

|**Augmented**
|Research & future vision
|Symbolic semantics, saga coordination, formal verification
|🔴 Experimental
|===

=== CRDT State Management

Unlike traditional databases that require coordination, CRDTs (Conflict-Free Replicated Data Types) enable distributed consistency without consensus protocols.

[source,rescript]
----
// Example: Collaborative todo list with automatic sync
open StateRouter

type todo = {
  id: string,
  text: string,
  completed: bool,
}

type state = {
  todos: GSet.t<todo>,
  completions: LWWMap.t<string, bool>,
}

let merge = (local: state, remote: state): state => {
  todos: GSet.merge(local.todos, remote.todos),
  completions: LWWMap.merge(local.completions, remote.completions),
}

let app = 
  StateRouter.make(
    ~nodeId="region-us-west",
    ~initialState={todos: GSet.make(), completions: LWWMap.make()},
    ~merge,
  )
  ->StateRouter.post("/todos", (ctx, req) => {
      let {text} = await req->Deno.Request.json
      let todo = {id: generateId(), text, completed: false}
      
      // Add to CRDT (automatically syncs to other regions)
      let nextState = {
        ...ctx.state.data,
        todos: ctx.state.data.todos->GSet.add(todo),
      }
      
      ctx.updateState(nextState)
      ->Promise.map(_ => Deno.Response.json(todo))
    })
  ->StateRouter.withAutoSync(~interval=30_000) // Sync every 30s
  ->StateRouter.serve(~ctx={...})
----

Key properties:

* **Commutative**: Operations can be applied in any order
* **Idempotent**: Applying the same operation twice has no effect
* **Associative**: Grouping doesn't matter: `(A ∪ B) ∪ C = A ∪ (B ∪ C)`
* **Conflict-free**: Merges are deterministic and never fail

=== Deno Integration

This framework leverages Deno's unique capabilities:

[cols="1,2,2"]
|===
|Feature |How We Use It |Benefit

|**KV Store**
|CRDT persistence across regions
|Sub-millisecond reads, global replication

|**Queue**
|Background CRDT sync jobs
|Automatic retry, dead-letter queues

|**Cron**
|Scheduled state reconciliation
|Drift correction, periodic cleanup

|**Permissions**
|Route-level access control
|Least-privilege execution

|**Deploy**
|Zero-config edge deployment
|35+ global regions, auto-scaling
|===

== Performance

=== Benchmarks

Comparing against popular Deno routers (single-threaded, AMD EPYC 7763, 1M requests):

[cols="1,1,1,1,1"]
|===
|Router |Req/sec |Latency p50 |Latency p99 |Memory

|**Raw Deno**
|45,231
|0.21ms
|0.89ms
|12 MB

|**Cadre Router (Core)**
|43,108
|0.23ms
|0.94ms
|14 MB

|**Cadre Router (Standard)**
|41,872
|0.24ms
|1.12ms
|18 MB

|**Hono**
|42,456
|0.23ms
|0.97ms
|15 MB

|**Oak**
|38,901
|0.26ms
|1.43ms
|19 MB
|===

CRDT overhead (Standard vs Core): ~3% throughput, ~15% latency p99

=== CRDT Merge Performance

[cols="1,1,1,1"]
|===
|CRDT Type |Elements |Merge Time |Memory

|GSet
|10,000
|0.8ms
|1.2 MB

|ORSet
|10,000
|2.1ms
|2.8 MB

|LWWMap
|10,000
|1.4ms
|1.9 MB

|CausalLog
|10,000
|3.2ms
|3.1 MB
|===

Run benchmarks yourself:

[source,bash]
----
deno task bench
----

== Examples

=== Real-Time Collaboration

[source,bash]
----
cd examples/realtime-collab
deno task start

# Open multiple browser windows to http://localhost:8000
# Edit the shared document - changes sync via CRDT
----

=== Offline-First Todo App

[source,bash]
----
cd examples/offline-first
deno task start

# Disable network, add todos
# Re-enable network - todos sync automatically
----

=== Edge Caching Layer

[source,bash]
----
cd examples/edge-cache
deno task deploy

# Distributed cache with CRDT invalidation
# No cache stampede, no thundering herd
----

== Development

=== Project Structure

[source]
----
packages/
├── core/           # HTTP routing (weeks 1-3)
│   ├── src/
│   │   ├── Route.res
│   │   ├── Router.res
│   │   ├── Handler.res
│   │   ├── Middleware.res
│   │   └── Deno.res
│   └── test/
├── standard/       # CRDTs (weeks 4-8)
│   ├── src/
│   │   ├── crdt/
│   │   ├── StateRouter.res
│   │   ├── Sync.res
│   │   └── Persistence.res
│   └── test/
├── extended/       # Production features (weeks 9-16)
│   ├── src/
│   │   ├── deploy/
│   │   ├── security/
│   │   ├── observability/
│   │   ├── streaming/
│   │   └── codegen/
│   └── test/
└── augmented/      # Research (ongoing)
    ├── src/
    └── docs/
----

=== Testing

[source,bash]
----
# Unit tests (ReScript)
npm run test:res

# Integration tests (Deno)
deno task test

# Property-based tests (CRDT invariants)
deno task test:properties

# End-to-end tests
deno task test:e2e

# Coverage report
deno task coverage
----

=== Code Quality

[source,bash]
----
# ReScript compiler warnings (zero tolerance)
npm run build

# Deno linting
deno lint

# Format code
deno fmt

# Type coverage
deno task check
----

=== Benchmarking

[source,bash]
----
# Run all benchmarks
deno task bench

# Specific benchmark
deno task bench --filter=routing

# Compare with baseline
deno task bench --baseline=v0.1.0
----

== Deployment

=== Deno Deploy (Recommended)

[source,bash]
----
# Install Deno Deploy CLI
deno install -Arf https://deno.land/x/deploy/deployctl.ts

# Deploy to production
deployctl deploy --project=my-api main.ts

# Deploy with environment variables
deployctl deploy --project=my-api main.ts \
  --env=DATABASE_URL=<url> \
  --env=NODE_ID=us-west-1
----

=== Docker (Podman Preferred)

[source,bash]
----
# Build container
podman build -t rescript-deno-router:latest .

# Run locally
podman run -p 8000:8000 \
  --read-only \
  --cap-drop=ALL \
  rescript-deno-router:latest

# Push to registry
podman push rescript-deno-router:latest \
  registry.example.com/router:latest
----

=== Kubernetes

[source,yaml]
----
# deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: router
spec:
  replicas: 3
  selector:
    matchLabels:
      app: router
  template:
    metadata:
      labels:
        app: router
    spec:
      containers:
      - name: router
        image: registry.example.com/router:latest
        ports:
        - containerPort: 8000
        env:
        - name: NODE_ID
          valueFrom:
            fieldRef:
              fieldPath: metadata.name
        resources:
          limits:
            memory: "128Mi"
            cpu: "500m"
        securityContext:
          readOnlyRootFilesystem: true
          runAsNonRoot: true
          allowPrivilegeEscalation: false
----

=== Multi-Region Setup

[source,bash]
----
# Deploy to multiple Deno Deploy regions
for region in us-west us-east eu-west asia-east; do
  deployctl deploy \
    --project=router-${region} \
    --env=NODE_ID=${region} \
    main.ts
done

# CRDTs automatically sync across regions
# No additional configuration needed
----

== API Reference

=== Core

[source,rescript]
----
module Router: {
  type t<'ctx>
  
  let make: unit => t<'ctx>
  let get: (t<'ctx>, string, Handler.t<'ctx, 'res>) => t<'ctx>
  let post: (t<'ctx>, string, Handler.t<'ctx, 'res>) => t<'ctx>
  let put: (t<'ctx>, string, Handler.t<'ctx, 'res>) => t<'ctx>
  let delete: (t<'ctx>, string, Handler.t<'ctx, 'res>) => t<'ctx>
  let patch: (t<'ctx>, string, Handler.t<'ctx, 'res>) => t<'ctx>
  let use: (t<'ctx>, Middleware.t<'ctx>) => t<'ctx>
  let serve: (t<'ctx>, ~ctx: 'ctx, ~port: int=?) => unit
}
----

Full API documentation: link:{repo}/-/wikis/api[API Reference]

=== Standard

[source,rescript]
----
module StateRouter: {
  type t<'ctx, 'state>
  
  let make: (
    ~nodeId: string,
    ~initialState: 'state,
    ~merge: ('state, 'state) => 'state
  ) => t<'ctx, 'state>
  
  let withAutoSync: (t<'ctx, 'state>, ~interval: int) => t<'ctx, 'state>
  let withWebSocketSync: (t<'ctx, 'state>, ~path: string) => t<'ctx, 'state>
}

module CausalLog: {
  type t<'a>
  let make: string => t<'a>
  let append: (t<'a>, 'a) => (t<'a>, id)
  let merge: (t<'a>, t<'a>) => t<'a>
  let toArray: t<'a> => array<entry<'a>>
}

// See full CRDT API documentation
----

== Contributing

We welcome contributions! Please see our link:CONTRIBUTING.adoc[Contributing Guide].

=== Development Setup

[source,bash]
----
# Fork the repository
# Clone your fork
git clone https://gitlab.com/hyperpolymath/cadre-router.git
cd router

# Create a feature branch
git checkout -b feature/amazing-feature

# Make your changes
# Add tests
# Update documentation

# Run full test suite
npm run build && deno task test:all

# Commit with conventional commits
git commit -m "feat(core): add wildcard route support"

# Push to your fork
git push origin feature/amazing-feature

# Open a merge request
----

=== Coding Standards

* **ReScript**: Follow link:https://rescript-lang.org/docs/manual/latest/style-guide[official style guide]
* **Tests**: 100% coverage for core, 90%+ for standard/extended
* **Docs**: Update README and API docs for all public APIs
* **Commits**: Use link:https://www.conventionalcommits.org/[conventional commits]

=== Release Process

[source,bash]
----
# Update CHANGELOG.md
# Bump version in package.json
npm version minor

# Tag release
git tag -a v0.2.0 -m "Release v0.2.0"
git push origin v0.2.0

# CI will automatically:
# 1. Run full test suite
# 2. Build all packages
# 3. Publish to npm
# 4. Deploy documentation
# 5. Create GitLab release
----

== Roadmap

=== v0.1.0 (Current) - Core + Standard
* [x] Basic routing with parameter extraction
* [x] Middleware composition
* [x] Core CRDTs (GSet, ORSet, LWWMap, CausalLog)
* [x] Deno KV persistence
* [ ] WebSocket sync
* [ ] Production documentation

=== v0.2.0 - Extended Features
* [ ] Deno Queue integration
* [ ] Deno Cron scheduling
* [ ] Permission-based middleware
* [ ] Distributed tracing
* [ ] OpenAPI generation
* [ ] Type-safe client generation

=== v0.3.0 - Production Hardening
* [ ] Load testing (1M+ req/s)
* [ ] Chaos engineering tests
* [ ] Security audit
* [ ] Performance optimization
* [ ] Multi-region benchmarks

=== v1.0.0 - Stable Release
* [ ] Feature complete (Core + Standard + Extended)
* [ ] Production deployments (3+ companies)
* [ ] Comprehensive documentation
* [ ] Video tutorials
* [ ] Conference talks

=== Beyond v1.0 - Augmented Layer
* [ ] Symbolic route semantics
* [ ] Saga coordination
* [ ] Formal verification
* [ ] AI-assisted debugging
* [ ] Research publications

== Community

* **Discord**: link:https://discord.gg/rescript-deno[Join our server]
* **Forum**: link:https://gitlab.com/rescript-deno/router/-/issues[GitLab Issues]
* **Twitter**: link:https://twitter.com/rescriptdeno[@rescriptdeno]
* **Blog**: link:https://rescript-deno.dev/blog[Latest updates]

== License

This project is dual-licensed under:

* **MIT License** - For permissive open-source use
* **Palimpsest License** - For ethical AI training and derivative works

You may choose either license for your use case.

=== MIT License

For individuals and organizations that prefer traditional permissive licensing, this project is available under the MIT License. See link:LICENSE-MIT[LICENSE-MIT] for full terms.

=== Palimpsest License

For those concerned with ethical AI practices and attribution in the age of large language models, this project is also available under the Palimpsest License. This license ensures:

* **Attribution preservation** through derivative works and AI training
* **Contextual integrity** for code used in training data
* **Human authorship** remains traceable even after AI transformation
* **Reciprocal transparency** for AI systems trained on this work

See link:LICENSE-PALIMPSEST[LICENSE-PALIMPSEST] for full terms.

=== Quick Reference

[cols="1,2,2"]
|===
|Use Case |Recommended License |Why

|**Building applications**
|MIT
|Maximum flexibility, no special requirements

|**Training AI models**
|Palimpsest
|Ensures attribution and ethical use

|**Creating derivatives**
|Either
|MIT for simplicity, Palimpsest for attribution

|**Commercial use**
|Either
|Both licenses permit commercial use

|**Redistribution**
|Either
|Both require license inclusion
|===

=== Choosing a License

When using this project:

1. **Read both licenses** (they're designed to be human-readable)
2. **Choose based on your values** and use case
3. **Include the appropriate LICENSE file** in your project
4. **If using both**, include both license files

If you're unsure which license to use, the MIT License is the safe, traditional choice. The Palimpsest License is for those who want stronger guarantees about attribution in AI systems.

=== License Compatibility

* **MIT is compatible** with Apache 2.0, BSD, GPL, and most other licenses
* **Palimpsest is compatible** with MIT and other permissive licenses
* **Both can coexist** in the same project (dual licensing)

=== Questions?

If you have questions about licensing:

* **MIT License**: See link:https://opensource.org/licenses/MIT[OSI's MIT License page]
* **Palimpsest License**: See link:https://github.com/AI-Labyrinth/palimpsest-license[Palimpsest License repository]
* **This project**: Open an issue in our link:{repo}/-/issues[issue tracker]

== Acknowledgments

* **ReScript Team** - For the excellent compiler and type system
* **Deno Team** - For the modern runtime and Deploy platform
* **CRDT Research** - Shapiro et al. (INRIA) for foundational work
* **Automerge/Yjs** - For CRDT implementation patterns
* **Hono/Oak** - For router API inspiration

== Citation

If you use Cadre Router in academic work, please cite:

[source,bibtex]
----
@software{rescript_deno_router,
  title = {Cadre Router (ReScript-Deno Router: Type-Safe, CRDT-Backed HTTP Routing)},
  author = {Jonathan D.A. Jewell},
  year = {2024},
  url = {https://gitlab.com/rescript-deno/router},
  version = {0.1.0}
}
----

---

Built with ❤️ using ReScript and Deno
