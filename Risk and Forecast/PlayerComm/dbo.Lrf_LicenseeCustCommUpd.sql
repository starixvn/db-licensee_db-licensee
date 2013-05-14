set ANSI_NULLS ON
set QUOTED_IDENTIFIER ON
go

ALTER PROCEDURE [dbo].[Lrf_LicenseeCustCommUpd]
	@LicenseeID INT,
	@strCustID VARCHAR(MAX),--member
	@UserID INT,
	@SBComm DECIMAL(9,8),
	@NGComm DECIMAL(9,8),	
	@RacingComm DECIMAL(9,8),
	@IsUpdateNG BIT = 0,
	@IsUpdateRacing BIT = 0,
	@IP VARCHAR(40),
	@Langkey NVARCHAR(10)='en-US',
	@ErrCode INT = 0 OUTPUT,
	@ErrMsg varchar(8000) = '' OUTPUT
AS

/*
Created: 20120726@Henry
Task : Update Commission of Player
DB: DB052.bodb_Licensee

Revisions:
	-20130413@Jim: support multi language
Param's Explanation:
*/ 

DECLARE @TempCustID  AS TABLE (ID int IDENTITY(1,1),CustID INT)
	INSERT INTO @TempCustID (CustID)
	SELECT CustID 
	FROM LicenseeCustComm WITH (NOLOCK) 
	WHERE LicenseeID = @LicenseeID 
			AND CustID IN (SELECT RTRIM(LTRIM(VAL)) FROM strSplit(@strCustID,','))


EXEC [Lrf_CustomerUpdMemberComm] @LicenseeID=@LicenseeID,@strCustID=@strCustID,@UserID=@UserID,@SBComm=@SBComm,@NGComm=@NGComm,@RacingComm=@RacingComm,@IsUpdateNG=@IsUpdateNG,@IsUpdateRacing=@IsUpdateRacing,@IP=@IP,@Langkey=@Langkey,@ErrCode=@ErrCode OUTPUT,@ErrMsg=@ErrMsg OUTPUT

UPDATE LicenseeCustComm WITH (ROWLOCK,UPDLOCK) SET GroupCommID=0
		WHERE LicenseeID = @LicenseeID 
			AND CustID IN (SELECT CustID FROM @TempCustID)


GO
GRANT EXECUTE ON [dbo].[Lrf_LicenseeCustCommUpd] TO [bodbLicenseeNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_LicenseeCustCommUpd] TO [vnteam] 