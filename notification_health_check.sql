-- Notification system health check — paste the whole thing in the Supabase
-- SQL Editor and run. Each block tells you whether one link of the chain is
-- alive. Read the comments above each block for what "good" looks like.

-- 1. Push dispatch settings (v33: stored in app_settings). BAD if the url row
--    is missing — then the dispatch trigger no-ops and no push is ever sent.
--    A missing secret row is fine as long as send-push has no
--    FUNCTIONS_SHARED_SECRET env secret set.
SELECT
  (SELECT value FROM app_settings WHERE key = 'push_functions_url') AS push_functions_url,
  CASE
    WHEN COALESCE((SELECT value FROM app_settings WHERE key = 'push_functions_secret'), '') = ''
    THEN 'not set (ok if function has no FUNCTIONS_SHARED_SECRET)'
    ELSE '✅ set'
  END AS push_secret_status;

-- 2. Dispatch triggers exist on both notification tables. Expect 2 rows.
SELECT event_object_table AS table_name, trigger_name
FROM information_schema.triggers
WHERE trigger_name IN ('meal_notification_push_dispatch', 'finance_notification_push_dispatch');

-- 3. Daily finance-alert cron job (v28). Expect 1 active row.
--    NOTE: schedule is UTC — '0 7 * * *' = 1:00 PM Dhaka time.
SELECT jobname, schedule, active FROM cron.job WHERE jobname = 'finance-alerts-daily';

-- 4. Did the cron actually run lately, and did it succeed?
SELECT j.jobname, d.status, d.return_message, d.start_time
FROM cron.job_run_details d JOIN cron.job j ON j.jobid = d.jobid
ORDER BY d.start_time DESC LIMIT 5;

-- 5. Recent pg_net calls to send-push: status_code 200 = push delivered to the
--    function. Errors/timeouts here mean dispatch is failing silently.
SELECT id, status_code, (content::json->>'sent') AS sent, error_msg, created
FROM net._http_response ORDER BY id DESC LIMIT 10;

-- 6. Registered devices — no rows means no phone can receive push at all.
SELECT platform, COUNT(*) AS devices, MAX(updated_at) AS last_registered
FROM fcm_tokens GROUP BY platform;

-- 7. Recent notification rows actually being written.
SELECT 'meal' AS src, COUNT(*) AS last_7_days FROM meal_notifications WHERE created_at > NOW() - INTERVAL '7 days'
UNION ALL
SELECT 'finance', COUNT(*) FROM finance_notifications WHERE created_at > NOW() - INTERVAL '7 days';
