def upgrade ta, td, a, d
  %w(use_gitbarclamp use_pip_cache use_gitrepo use_virtualenv pfs_deps).each do |attr|
    a.delete(attr)
  end
  return a, d
end

def downgrade ta, td, a, d
  %w(use_gitbarclamp use_pip_cache use_gitrepo use_virtualenv pfs_deps).each do |attr|
    a[attr] = ta[attr]
  end
  return a, d
end
