/*<info serverAlias="DBLIC-bodb_Licensee" executers="bodbLicenseeNet" viewers="vnteam" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[DBA_Lrf_ActiveBetSettingFunc]  
(  
	@LicenseeNames  VARCHAR (500)
)  
AS  

/*
	Created: 20170920@Harper
	Description : Active 2 special func for licensee if requested
	DB: DBLIC.bodb_licensee  
	
	Revisions:  
	  - 20150320@Harper: Document LRF Setting [RedmineID: #82673]
*/
BEGIN
	
	DECLARE @tmpLicensee AS TABLE (ID INT IDENTITY(1,1), LicenseeID INT)
	INSERT INTO @tmpLicensee (LicenseeID)
	SELECT LicenseeID
	FROM dbo.Licensees (NOLOCK)
	WHERE LicenseeName IN ( SELECT val FROM bodb02.dbo.strSplit(@LicenseeNames, ',') )
	
	DECLARE @tmpFunction AS TABLE (ID INT IDENTITY(1,1), FunctionID INT )
	INSERT INTO @tmpFunction (FunctionID)
	SELECT FunctionID 
	FROM dbo.Functions WITH (NOLOCK)
	WHERE Name IN ('Edit Bet Setting','Customer List')

	DECLARE @tmplicenseeuserfunctions AS TABLE (UserID INT ,FunctionID INT,LicenseeID INT)

	UPDATE l
	SET EditBetSetting = 1 
	FROM licensees l WITH (NOLOCK)
		INNER JOIN @tmpLicensee t ON l.LicenseeId = t.LicenseeId

	DECLARE @i				INT
			,@maxID			INT
			,@FunctionID	INT

	SELECT @i= 1 
			,@maxID = MAX(ID)	
	FROM  @tmpFunction

	WHILE (@i <= @maxID)		
	BEGIN
		SELECT @FunctionID = FunctionID
		FROM @tmpFunction
		WHERE ID = @i
		
		INSERT INTO dbo.LicenseeFunctions (LicenseeId,FunctionId)
		SELECT LicenseeID,@FunctionID
		FROM @tmpLicensee
		WHERE LicenseeID NOT IN (	SELECT lf.LicenseeID 
									FROM dbo.LicenseeFunctions lf WITH (NOLOCK) 
										INNER JOIN @tmpLicensee t ON lf.LicenseeId = t.LicenseeID
									WHERE lf.FunctionID = @FunctionID
								)

		INSERT INTO @tmplicenseeuserfunctions (UserID,FunctionID,LicenseeID)												
		SELECT UserId,@FunctionID,luf.LicenseeID
		FROM dbo.LicenseeUserFunctions luf WITH (NOLOCK)
			INNER JOIN @tmpLicensee t ON luf.LicenseeID = t.LicenseeID
		 
		SET @i = @i +1
	END
	
	INSERT INTO dbo.LicenseeUserFunctions ( UserId, FunctionId, LicenseeId )	         
	SELECT a.UserID,a.FunctionID,a.LicenseeID
	FROM @tmplicenseeuserfunctions a
	EXCEPT
	SELECT b.UserID,b.FunctionID,b.LicenseeID
	FROM LicenseeUserFunctions b WITH (NOLOCK)
		INNER JOIN @tmpLicensee t ON b.LicenseeID = t.LicenseeID 
END
GO