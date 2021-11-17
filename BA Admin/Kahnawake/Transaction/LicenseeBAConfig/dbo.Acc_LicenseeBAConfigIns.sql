ALTER PROCEDURE [dbo].[Acc_LicenseeBAConfigIns]  
	@LicenseeId INT,
	@1x2Comm decimal(9,8),
	@OtherComm decimal(9,8),
	@groupa decimal(9,8),
	@groupb decimal(9,8),
	@groupc decimal(9,8),
	@groupd decimal(9,8)
	
AS  
/*  Created: Henry  
	Date: 2012-02-22
    TASk : Insert data to LicenseeBAConfig in Kahnawake server
    DB: bodb_MoveBet
   
    Revisions:  
		
	Param's Explanation:  
*/  
BEGIN  
SET NOCOUNT ON  
	--Delete before insert
	IF EXISTS (SELECT 1 FROM LicenseeBAConfig WITH (NOLOCK) WHERE LicenseeID = @LicenseeId)
	BEGIN
		DELETE FROM LicenseeBAConfig WITH (ROWLOCK,UPDLOCK)
		WHERE LicenseeID = @LicenseeId
	END

	INSERT INTO [dbo].LicenseeBAConfig
           (LicenseeID
           ,[1x2Comm]
           ,OtherComm
           ,groupa
           ,groupb 
           ,groupc 
           ,groupd
           )
     VALUES	
     (
		@LicenseeId,
		@1x2Comm,
		@OtherComm,
		@groupa,
		@groupb,
		@groupc,
		@groupd 
     )

END   

GO
GRANT EXECUTE ON [dbo].[Acc_LicenseeBAConfigIns] TO [bodbAdminNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Acc_LicenseeBAConfigIns] TO [vnteam] 

    