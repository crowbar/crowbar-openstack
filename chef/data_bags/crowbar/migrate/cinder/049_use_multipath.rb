def upgrade(ta, td, a, d)
  unless a.key? "use_multipath"
    a["use_multipath"] = ta["use_multipath"]
  end
  return a, d
end

def downgrade(ta, td, a, d)
  unless ta.key? "use_multipath"
    del a["use_multipath"]
  end
  return a, d
end
