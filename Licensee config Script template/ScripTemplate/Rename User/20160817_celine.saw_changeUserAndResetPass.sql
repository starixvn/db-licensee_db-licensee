USE bodb_licensee
GO
DECLARE @UserID INT
SELECT @UserID = UserID
FROM dbo.Users WITH (NOLOCK)
WHERE Username = 'dbaScott'

SELECT @UserID
-- change username and reset pass
UPDATE dbo.Users WITH (ROWLOCK,UPDLOCK)
SET Username = 'celine.saw'
	,UserPwd ='D7B4B645DF55118909C6ABD46803AA69788060BE'
	,UserSalt = '5lm3rAq9Yjw7Svq/Mw=='
	,Status = 'Open'
WHERE UserID = @UserID	
-- grant permission on 12bet 
UPDATE dbo.LicenseeUser WITH (ROWLOCK,UPDLOCK)
SET isActive = CASE WHEN LicenseeID = 1 THEN 1 ELSE 0 END
WHERE UserID = @UserID
 