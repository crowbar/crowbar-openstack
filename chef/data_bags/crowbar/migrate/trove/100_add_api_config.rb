# ta->template_attributes, td->template_deployment, a->attributes, d->deployment
def upgrade(ta, td, a, d)
  a["api"] = ta["api"]
  return a, d
end

def downgrade(ta, td, a, d)
  a.delete("api")
  return a, d
end
