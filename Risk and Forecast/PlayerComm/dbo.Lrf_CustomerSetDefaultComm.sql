set ANSI_NULLS ON
set QUOTED_IDENTIFIER ON
go

ALTER PROCEDURE [dbo].[Lrf_CustomerSetDefaultComm]
	@LicenseeName VARCHAR(50),
	@CustID INT,--member
	@Langkey VARCHAR(10) = 'en-US',
	@ErrCode INT = 0 OUTPUT,
	@ErrMsg nvarchar(2000) = '' OUTPUT
AS

/*
Created: 20121227@Henry
Task : Update Default Commission of Player
DB: DB052.bodb_Licensee

Revisions:
	- 20130413@Jim: support multi language
Param's Explanation:
*/ 

DECLARE @GroupCommID INT, @IsUpdateNG BIT, @IsUpdateRacing BIT, @LicenseeID INT, @strCustID VARCHAR(50)

--Get LicenseeID
SELECT @LicenseeID = LicenseeID FROM Licensees WITH (NOLOCK) WHERE LicenseeName = @LicenseeName


IF ISNULL(@LicenseeID,0)>0
BEGIN
	SELECT TOP 1 @GroupCommID=ID FROM LicenseeGroupComm WITH (NOLOCK) WHERE LicenseeID=@LicenseeID AND IsDefault=1 AND IsActive=1
	IF ISNULL(@GroupCommID,0)>0
	BEGIN
		IF EXISTS ( SELECT TOP 1 1 FROM LicenseeProduct3rd WITH (NOLOCK) WHERE LicenseeID=@LicenseeID AND ProductID=2)
			SELECT @IsUpdateNG = 1
		ELSE
			SELECT @IsUpdateNG = 0
			
		IF EXISTS ( SELECT TOP 1 1 FROM LicenseeProduct3rd WITH (NOLOCK) WHERE LicenseeID=@LicenseeID AND ProductID=1)
			SELECT @IsUpdateRacing = 1
		ELSE
			SELECT @IsUpdateRacing = 0		
		
		SELECT @strCustID=CAST (@CustID AS VARCHAR(50))
		
		EXEC [Lrf_CustomerUpdMemberComm] @LicenseeID=@LicenseeID,@strCustID=@strCustID,@UserID=0,@GroupCommID=@GroupCommID,@IsUpdateNG=@IsUpdateNG,@IsUpdateRacing=@IsUpdateRacing,@IP='',@Langkey=@Langkey,@ErrCode=@ErrCode OUTPUT,@ErrMsg=@ErrMsg OUTPUT

	END
END


GO
GRANT EXECUTE ON [dbo].[Lrf_CustomerSetDefaultComm] TO [Dot_Member] AS [dbo]
GO
GRANT EXECUTE ON [dbo].[Lrf_CustomerSetDefaultComm] TO [bodbLicenseeNet]
GO
GRANT EXECUTE ON [dbo].[Lrf_CustomerSetDefaultComm] TO [bodbAdminNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_CustomerSetDefaultComm] TO [vnteam]  
