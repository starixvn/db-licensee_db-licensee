/*<info serverAlias="DBLIC-bodb_Licensee" executers="bodbLicenseeNet" viewers="vnteam" isFunction="0"></info>*/ 
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
DB: DBLIC/bodb_Licensee

Revisions:
	- 20130413@Jim: support multi language
	- 20131023@Hannah: offer Live Casino Commission
	- 20131126@Hannah: offer RNG Casino commission
	- 20171024@Johnson: offer Allbet commision [Redmine: #82036]
	- 20180228@Vicky: Remove LC from product list [Redmine: #85965]
	- 20180809@Amanda: Remove Racing [RedmineID: #99378]
	- 20180927@Winnie: Remove AllBet [RedmineID: #99378]
Param's Explanation:
*/ 
BEGIN
	SET NOCOUNT ON 
	
	DECLARE @GroupCommID INT, 
		@IsUpdateNG BIT,
		@IsUpdateRNG BIT, 	
		@LicenseeID INT, 
		@strCustID VARCHAR(50)

	--Get LicenseeID
	SELECT @LicenseeID = LicenseeID 
	FROM Licensees WITH (NOLOCK) 
	WHERE LicenseeName = @LicenseeName

	IF ISNULL(@LicenseeID,0)>0
	BEGIN
		SELECT TOP 1 @GroupCommID=ID FROM LicenseeGroupComm WITH (NOLOCK) WHERE LicenseeID=@LicenseeID AND IsDefault=1 AND IsActive=1
		IF ISNULL(@GroupCommID,0)>0
		BEGIN
			IF EXISTS ( SELECT TOP 1 1 FROM LicenseeProduct3rd WITH (NOLOCK) WHERE LicenseeID=@LicenseeID AND ProductID=2)
				SELECT @IsUpdateNG = 1
			ELSE
				SELECT @IsUpdateNG = 0

			/*IF EXISTS ( SELECT TOP 1 1 FROM LicenseeProduct3rd WITH (NOLOCK) WHERE LicenseeID=@LicenseeID AND ProductID=4)
				SELECT @IsUpdateLC = 1
			ELSE
				SELECT @IsUpdateLC = 0	*/

			IF EXISTS ( SELECT TOP 1 1 FROM LicenseeProduct3rd WITH (NOLOCK) WHERE LicenseeID=@LicenseeID AND ProductID=6)
				SELECT @IsUpdateRNG = 1
			ELSE
				SELECT @IsUpdateRNG = 0	
			
			SELECT @strCustID=CAST (@CustID AS VARCHAR(50))
			
			EXEC [Lrf_CustomerUpdMemberComm] 
				@LicenseeID=@LicenseeID
				,@strCustID=@strCustID
				,@UserID=0
				,@GroupCommID=@GroupCommID
				,@IsUpdateNG=@IsUpdateNG
				--,@IsUpdateLC=@IsUpdateLC
				,@IsUpdateRNG=@IsUpdateRNG				
				,@IP=''
				,@Langkey=@Langkey
				,@ErrCode=@ErrCode OUTPUT
				,@ErrMsg=@ErrMsg OUTPUT

		END
	END
END
GO

