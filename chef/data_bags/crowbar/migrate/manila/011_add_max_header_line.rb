def upgrade(ta, td, a, d)
  unless a.has_key? "max_header_line"
    a["max_header_line"] = ta["max_header_line"]
  end
  return a, d
end

def downgrade(ta, td, a, d)
  unless ta.has_key? "max_header_line"
    a.delete("max_header_line")
  end
  return a, d
end
