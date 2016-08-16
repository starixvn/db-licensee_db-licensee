ALTER  PROCEDURE [dbo].[Lrf_CheckEditBetSetting]
	@UserId INT,  
	@LicenseeId INT
AS
/*
	Created by: [20160812@Jim:]
	Task: LRF - Set "Adjust bet settings" with separate authorization [RedmineID : #61999 ]
	DB: DBLIC/bodb_Licensee
	Revisions:
	
*/  
SET NOCOUNT ON  
 IF NOT EXISTS (SELECT 1 FROM dbo.Licensees WITH (NOLOCK) WHERE EditBetSetting = 1 AND AND LicenseeID = @LicenseeId) 
	BEGIN 
		SELECT @LicenseeID LicenseeID,@UserID UserID ,0 AS IsGrant
	END 
ELSE 
	BEGIN 
		DECLARE @isCustomerList BIT = 0
				,@isEditBetSetting BIT = 0
				,@CustomerListID INT = 43
				,@EditBettSettingID INT = 70
		SELECT @CustomerListID = FunctionID
		FROM dbo.Functions WITH (NOLOCK)
		WHERE Name = 'Customer List'	
		
		SELECT @EditBettSettingID = FunctionID
		FROM dbo.Functions WITH (NOLOCK)
		WHERE Name = 'Edit Bet Setting'
		
		IF EXISTS (SELECT 1 FROM dbo.LicenseeUserFunctions WITH (NOLOCK) WHERE LicenseeID = @LicenseeID AND UserID = @UserId AND FunctionID = @CustomerListID)		
			SET @isCustomerList = 1
			
		IF EXISTS (SELECT 1 FROM dbo.LicenseeUserFunctions WITH (NOLOCK) WHERE LicenseeID = @LicenseeID AND UserID = @UserId AND FunctionID = @EditBettSettingID)		
			SET @isEditBetSetting = 1
		
		
		SELECT @LicenseeID LicenseeID
			   ,@UserID UserID 
			   ,@isCustomerList
			   ,@isCustomerList & @isEditBetSetting  IsGrant	
			
    END
GO
GRANT EXECUTE ON [dbo].[Lrf_CheckEditBetSetting] TO [bodbLicenseeNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_CheckEditBetSetting] TO [vnteam]
 