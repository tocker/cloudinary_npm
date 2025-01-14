workflow "New workflow" {
  on = "push"
  resolves = ["compile"]
}

action "install" {
  uses = "actions/npm@59b64a598378f31e49cb76f27d6f3312b582f680"
  args = "install"
}

action "compile" {
  uses = "actions/npm@59b64a598378f31e49cb76f27d6f3312b582f680"
  needs = ["install"]
  args = "run compile"
}
