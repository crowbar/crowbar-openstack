def upgrade(ta, td, a, d)
  unless a.key? "migration"
    a["migration"] = ta["migration"]
  end
  return a, d
end

def downgrade(ta, td, a, d)
  unless ta.key? "migration"
    a.delete("migration")
  end
  return a, d
end
