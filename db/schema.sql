-- ============================================================================
--  Kickoff (ManToMan) — users table + seed admin
--  Target: Azure SQL Database  "man-to-man"
--
--  HOW TO RUN
--  ----------
--  Easiest: Azure Portal -> your SQL database -> "Query editor (preview)" ->
--  sign in -> paste this whole file -> Run. The Query editor connects over
--  Azure's internal network, so it works even while the server has
--  "Deny public network access = Yes".
--
--  Or, once public access is enabled + your IP is allowed, run it from
--  SSMS / Azure Data Studio / sqlcmd against man-to-man.database.windows.net.
--
--  Safe to re-run: every statement is guarded with IF NOT EXISTS.
-- ============================================================================

-- ── Table ────────────────────────────────────────────────────────────────
IF OBJECT_ID(N'dbo.users', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.users (
        id             INT IDENTITY(1,1) PRIMARY KEY,
        first_name     NVARCHAR(80)   NOT NULL,
        last_name      NVARCHAR(80)   NOT NULL,
        email          NVARCHAR(256)  NOT NULL,
        phone          NVARCHAR(40)   NULL,
        date_of_birth  DATE           NULL,
        username       NVARCHAR(60)   NULL,          -- admin logs in with this; members use email
        password       NVARCHAR(256)  NOT NULL,      -- see note about hashing below
        club_team      NVARCHAR(120)  NULL,          -- supported club
        national_team  NVARCHAR(120)  NULL,          -- supported national team
        is_admin       BIT            NOT NULL CONSTRAINT DF_users_is_admin DEFAULT (0),
        created_at     DATETIME2(0)   NOT NULL CONSTRAINT DF_users_created  DEFAULT (SYSUTCDATETIME())
    );
END
GO

-- Unique-but-nullable email / username (a member may have no username).
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'UQ_users_email')
    CREATE UNIQUE INDEX UQ_users_email
        ON dbo.users(email) WHERE email IS NOT NULL;
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'UQ_users_username')
    CREATE UNIQUE INDEX UQ_users_username
        ON dbo.users(username) WHERE username IS NOT NULL;
GO

-- ── Seed: admin test account (username "mantoman", password "123") ─────────
--  is_admin = 1. You CANNOT create an admin from the app's Sign-up screen;
--  the only way to get an admin is this row (or flipping is_admin in the DB).
IF NOT EXISTS (SELECT 1 FROM dbo.users WHERE username = N'mantoman')
BEGIN
    INSERT INTO dbo.users
        (first_name, last_name, email, phone, date_of_birth, username, password, club_team, national_team, is_admin)
    VALUES
        (N'Man to Man', N'', N'admin@mantoman.app', NULL, NULL, N'mantoman', N'123', N'', N'', 1);
END
GO

-- ── Optional: a demo community member (matches the app's local demo data) ──
IF NOT EXISTS (SELECT 1 FROM dbo.users WHERE username = N'mahmoud')
BEGIN
    INSERT INTO dbo.users
        (first_name, last_name, email, phone, date_of_birth, username, password, club_team, national_team, is_admin)
    VALUES
        (N'Mahmoud', N'', N'mahmoud@example.com', NULL, NULL, N'mahmoud', N'123', N'Liverpool', N'Egypt', 0);
END
GO

SELECT id, username, email, club_team, national_team, is_admin, created_at
FROM dbo.users;
GO

-- ============================================================================
--  SECURITY NOTE
--  Passwords are stored in plain text here only because you asked for the test
--  account to be literally "123". For anything real, store a salted hash
--  (e.g. bcrypt/argon2) computed in your backend and compare hashes on login —
--  never ship the DB admin credentials inside the Flutter app.
-- ============================================================================
