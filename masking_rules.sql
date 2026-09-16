SECURITY LABEL FOR anon ON COLUMN "user".first_name
  IS 'MASKED WITH FUNCTION anon.dummy_first_name_locale(''fr_FR'')';
SECURITY LABEL FOR anon ON COLUMN "user".last_name
  IS 'MASKED WITH FUNCTION anon.dummy_last_name_locale(''fr_FR'')';
SECURITY LABEL FOR anon ON COLUMN "user".phone_number
  IS 'MASKED WITH FUNCTION anon.dummy_phone_number()';
SECURITY LABEL FOR anon ON COLUMN "user".email
  IS 'MASKED WITH FUNCTION anon.hash("user".id::text)';

SECURITY LABEL FOR anon ON COLUMN controller_user.first_name
  IS 'MASKED WITH FUNCTION anon.dummy_first_name_locale(''fr_FR'')';
SECURITY LABEL FOR anon ON COLUMN controller_user.last_name
  IS 'MASKED WITH FUNCTION anon.dummy_last_name_locale(''fr_FR'')';
SECURITY LABEL FOR anon ON COLUMN controller_user.email
  IS 'MASKED WITH FUNCTION anon.dummy_safe_email()';

SECURITY LABEL FOR anon ON COLUMN controller_control.user_first_name
  IS 'MASKED WITH FUNCTION anon.dummy_first_name_locale(''fr_FR'')';
SECURITY LABEL FOR anon ON COLUMN controller_control.user_last_name
  IS 'MASKED WITH FUNCTION anon.dummy_last_name_locale(''fr_FR'')';
SECURITY LABEL FOR anon ON COLUMN controller_control.company_name IS 'MASKED WITH VALUE NULL';

SECURITY LABEL FOR anon ON COLUMN employment.email
  IS 'MASKED WITH FUNCTION anon.dummy_safe_email()';

SECURITY LABEL FOR anon ON COLUMN email.address
  IS 'MASKED WITH FUNCTION anon.dummy_safe_email()';

SECURITY LABEL FOR anon ON COLUMN "user".password               IS 'MASKED WITH VALUE NULL';
SECURITY LABEL FOR anon ON COLUMN "user".ssn                    IS 'MASKED WITH VALUE NULL';
SECURITY LABEL FOR anon ON COLUMN "user".france_connect_id      IS 'MASKED WITH VALUE NULL';
SECURITY LABEL FOR anon ON COLUMN "user".france_connect_info    IS 'MASKED WITH VALUE NULL';
SECURITY LABEL FOR anon ON COLUMN "user".activation_email_token IS 'MASKED WITH VALUE NULL';

SECURITY LABEL FOR anon ON COLUMN controller_user.agent_connect_id
  IS 'MASKED WITH FUNCTION anon.hash(controller_user.agent_connect_id)';
SECURITY LABEL FOR anon ON COLUMN controller_user.agent_connect_info IS 'MASKED WITH VALUE NULL';
SECURITY LABEL FOR anon ON COLUMN controller_user.greco_id          IS 'MASKED WITH VALUE NULL';

SECURITY LABEL FOR anon ON COLUMN oauth2_token.token
  IS 'MASKED WITH FUNCTION anon.hash(oauth2_token.token)';
SECURITY LABEL FOR anon ON COLUMN refresh_token.token
  IS 'MASKED WITH FUNCTION anon.hash(refresh_token.token)';
SECURITY LABEL FOR anon ON COLUMN controller_refresh_token.token
  IS 'MASKED WITH FUNCTION anon.hash(controller_refresh_token.token)';
SECURITY LABEL FOR anon ON COLUMN refresh_token.replaced_by_token            IS 'MASKED WITH VALUE NULL';
SECURITY LABEL FOR anon ON COLUMN controller_refresh_token.replaced_by_token IS 'MASKED WITH VALUE NULL';
SECURITY LABEL FOR anon ON COLUMN user_read_token.token
  IS 'MASKED WITH FUNCTION anon.hash(user_read_token.token)';
SECURITY LABEL FOR anon ON COLUMN employment.invite_token IS 'MASKED WITH VALUE NULL';
SECURITY LABEL FOR anon ON COLUMN third_party_client_employment.access_token     IS 'MASKED WITH VALUE NULL';
SECURITY LABEL FOR anon ON COLUMN third_party_client_employment.invitation_token IS 'MASKED WITH VALUE NULL';

SECURITY LABEL FOR anon ON COLUMN oauth2_client.secret
  IS 'MASKED WITH FUNCTION anon.random_string(32)';
SECURITY LABEL FOR anon ON COLUMN totp_credential.secret
  IS 'MASKED WITH FUNCTION anon.random_string(16)';

SECURITY LABEL FOR anon ON COLUMN oauth2_client.whitelist_ips IS 'MASKED WITH VALUE NULL';

SECURITY LABEL FOR anon ON COLUMN comment.text                        IS 'MASKED WITH VALUE ''''';
SECURITY LABEL FOR anon ON COLUMN vehicle.alias                       IS 'MASKED WITH VALUE NULL';
SECURITY LABEL FOR anon ON COLUMN company_known_address.alias         IS 'MASKED WITH VALUE NULL';
SECURITY LABEL FOR anon ON COLUMN controller_control.note             IS 'MASKED WITH VALUE NULL';
SECURITY LABEL FOR anon ON COLUMN controller_control.control_bulletin IS 'MASKED WITH VALUE NULL';
SECURITY LABEL FOR anon ON COLUMN notification.data                   IS 'MASKED WITH VALUE NULL';
SECURITY LABEL FOR anon ON COLUMN mission.past_registration_justification IS 'MASKED WITH VALUE NULL';

SECURITY LABEL FOR anon ON COLUMN activity.dismiss_context             IS 'MASKED WITH VALUE NULL';
SECURITY LABEL FOR anon ON COLUMN expenditure.dismiss_context          IS 'MASKED WITH VALUE NULL';
SECURITY LABEL FOR anon ON COLUMN comment.dismiss_context              IS 'MASKED WITH VALUE NULL';
SECURITY LABEL FOR anon ON COLUMN company_known_address.dismiss_context IS 'MASKED WITH VALUE NULL';
SECURITY LABEL FOR anon ON COLUMN employment.dismiss_context           IS 'MASKED WITH VALUE NULL';
SECURITY LABEL FOR anon ON COLUMN activity.dispute                     IS 'MASKED WITH VALUE NULL';
SECURITY LABEL FOR anon ON COLUMN activity_version.context             IS 'MASKED WITH VALUE NULL';
SECURITY LABEL FOR anon ON COLUMN mission_validation.context           IS 'MASKED WITH VALUE NULL';
SECURITY LABEL FOR anon ON COLUMN mission.context                      IS 'MASKED WITH VALUE NULL';
SECURITY LABEL FOR anon ON COLUMN export.context                       IS 'MASKED WITH VALUE NULL';
SECURITY LABEL FOR anon ON COLUMN export.file_name                     IS 'MASKED WITH VALUE NULL';

SECURITY LABEL FOR anon ON COLUMN support_action_log.old_values IS 'MASKED WITH VALUE NULL';
SECURITY LABEL FOR anon ON COLUMN support_action_log.new_values IS 'MASKED WITH VALUE NULL';

SECURITY LABEL FOR anon ON COLUMN vehicle.registration_number
  IS 'MASKED WITH FUNCTION anon.random_string(7)';
SECURITY LABEL FOR anon ON COLUMN controller_control.vehicle_registration_number
  IS 'MASKED WITH FUNCTION anon.random_string(7)';

SECURITY LABEL FOR anon ON COLUMN company.phone_number
  IS 'MASKED WITH FUNCTION anon.dummy_phone_number()';
