ALTER PROCEDURE dbo.[Lrf_CheckHRAllowedCurrency]
	@CustID INT,
	@Allowed BIT = 0 OUTPUT
AS
/*
Created: 20110408@Henry
DB: DB052.BODB02
Original: Acc_CheckHRAllowedCurrency


Revisions:
	
*/
SET NOCOUNT ON


DECLARE @Currency INT

SELECT @Currency=currency FROM Custinfo c with(nolock)
WHERE c.custid = @CustID

IF isnull(@Currency,0) = 0
BEGIN
	SET @Allowed = 0
END
ELSE
BEGIN
	IF EXISTS(SELECT 1 FROM f_GetHRAllowedCurr() WHERE exchangeID = @Currency)
		SET @Allowed = 1
	ELSE
		SET @Allowed = 0
END

GO
GRANT EXECUTE ON [dbo].[Lrf_CheckHRAllowedCurrency] TO [bodbLicenseeNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_CheckHRAllowedCurrency] TO [vnteam]
GO