def upgrade(ta, td, a, d)
  %w(use_slog slog_account slog_user slog_password).each do |attr|
    a.delete(attr)
  end
  return a, d
end

def downgrade(ta, td, a, d)
  %w(use_slog slog_account slog_user slog_password).each do |attr|
    a[attr] = ta[attr]
  end
  return a, d
end
