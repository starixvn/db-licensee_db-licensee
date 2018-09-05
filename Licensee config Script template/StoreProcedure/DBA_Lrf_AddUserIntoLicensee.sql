USE bodb_licensee
GO

ALTER PROCEDURE [dbo].[DBA_Lrf_AddUserIntoLicensee] (
	@LicenseeName VARCHAR(50)
	, @UserName VARCHAR(50)
	, @isSpecialAdmin BIT = 0
)
AS
/*  
	Created: 20150121@Jim  
	Task : #29593 (Add David to the list of users who can use XTD3)  
	DB: DBLIC.bodb_licensee  
	Original :  
   
	Revisions:  
		- 20150320@Harper: Document LRF Setting [RedmineID: #82673]
   
	Param's Explanation:    
   
*/
BEGIN
	DECLARE @LicenseeID INT

	SELECT @LicenseeID = LicenseeID
	FROM dbo.Licensees WITH (NOLOCK)
	WHERE LicenseeName = @LicenseeName

	IF ISNULL(@LicenseeID, 0) = 0
	BEGIN
		SELECT ISNULL(@LicenseeName, ''), 'Wrong LicenseeName,please have a check and try again'
		RETURN;
	END
	ELSE
	BEGIN
		DECLARE @UserID INT

		SELECT @UserID = UserID
		FROM dbo.Users WITH (NOLOCK)
		WHERE UserName = @UserName
			AND isInternal = 0

		IF ISNULL(@UserID, 0) = 0
		BEGIN
			SELECT 'This User does not exists,please check again'
			RETURN;
		END

		--- LicenseeUser  
		IF NOT EXISTS (
						SELECT 1
						FROM dbo.LicenseeUser WITH (NOLOCK)
						WHERE LicenseeID = @LicenseeId
							AND UserID = @UserID
					)
		BEGIN
			INSERT INTO dbo.LicenseeUser ( LicenseeId, UserId, isActive, PageAccess, ModifyDate, ModifyBy )
			SELECT @LicenseeID, @UserID, 1, '', NULL, NULL
		END

		--- LicenseeUserFunction  
		INSERT INTO dbo.LicenseeUserFunctions ( UserId, FunctionId, LicenseeId	)
		SELECT DISTINCT @UserID, luf.FunctionID, luf.LicenseeID
		FROM dbo.LicenseeFunctions luf WITH (NOLOCK)
		INNER JOIN dbo.Functions f WITH (NOLOCK) ON luf.FunctionId = luf.FunctionID
		WHERE luf.LicenseeId = @LicenseeID
			AND luf.FunctionID NOT IN (
										SELECT FunctionID
										FROM LicenseeUserFunctions WITH (NOLOCK)
										WHERE LicenseeID = @LicenseeID
											AND UserID = @UserID
									)
			AND ( @isSpecialAdmin = 1 OR ( @isSpecialAdmin <> 1	AND (f.FunctionId <> 6 AND f.ParentId <> 6 )))

		--- CurrencyUser  
		DELETE dbo.CurrencyUser
		WHERE LicenseeId = @LicenseeId
			AND usrID = @UserID

		INSERT INTO dbo.CurrencyUser (usrID, LicenseeId, CurrencyID, SystemId, isActive	)
		SELECT DISTINCT @UserId, LicenseeID, CurrencyID, 1, 1
		FROM dbo.CurrencyUser WITH (NOLOCK)
		WHERE LicenseeID = @LicenseeId
	END
END
