ALTER PROCEDURE [dbo].[Acc_ExchangeIns]  
	@ExchangeId INT,
	@currency nvarchar(50),
	@Code varchar(3) = null,
	@MultipliedBy int = null
AS  
/*  Created: Henry  
	Date: 2012-02-21
    TASk : Insert data to exchange in Kahnawake server
    DB: bodb_MoveBet
   
    Revisions:  
		
	Param's Explanation:  
*/  
BEGIN  
SET NOCOUNT ON  
	--Delete before insert
	IF EXISTS (SELECT 1 FROM exchange WITH (NOLOCK) WHERE exchangeid = @ExchangeId)
	BEGIN
		DELETE FROM exchange WITH (ROWLOCK,UPDLOCK)
		WHERE exchangeid = @ExchangeId
	END

	INSERT INTO [dbo].exchange
           (exchangeid
           ,currency
           ,code
           ,multipliedby
           )
     VALUES	
     (
		@ExchangeId,
		@currency,
		@Code,
		@MultipliedBy
     )

END   

GO
GRANT EXECUTE ON [dbo].[Acc_ExchangeIns] TO [bodbAdminNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Acc_ExchangeIns] TO [vnteam] 

  