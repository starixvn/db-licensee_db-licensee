ALTER PROCEDURE  [dbo].[Acc_SelCurrency]		
AS	
/*
Created: 20120713@Henry
Task : Get all the currency
DB: bodb_MoveBet


Revisions:
  
Param's Explanation:
*/

SET NOCOUNT ON
BEGIN
	
	SELECT 
		e.exchangeid as currency, 
		e.Code  AS CurrencyName
	FROM 
		exchange e with (nolock)
	WHERE e.exchangeid <> 20	
	ORDER BY 
		e.Code 

END

GO
GRANT EXECUTE ON [dbo].[Acc_SelCurrency] TO [bodbAdminNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Acc_SelCurrency] TO [vnteam]   