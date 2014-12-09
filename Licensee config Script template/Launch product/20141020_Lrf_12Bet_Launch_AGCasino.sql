 --- AGCasino
USE bodb_licensee
GO
 
DECLARE @LicenseeId INT
		 ,@ProductId INT
		 ,@EffectiveDate DATETIME
SELECT @LicenseeId = LicenseeId
FROM  dbo.Licensees WITH (NOLOCK)
WHERE LicenseeName = '12Bet'

SELECT @ProductId = ProductID
FROM dbo.Product3rd WITH (NOLOCK)
WHERE ProductName = 'AG Casino' 

SET @EffectiveDate = '2014-10-16'

IF  EXISTS (SELECT 1 FROM dbo.LicenseeProduct3rd WITH (NOLOCK) WHERE LicenseeId = @LicenseeId AND ProductId = @ProductId)
	BEGIN
		UPDATE LicenseeProduct3rd 
		SET  EffectiveDate = @EffectiveDate
		WHERE LicenseeId = @LicenseeId AND ProductId = @ProductId
	END
ELSE 
	BEGIN
		INSERT INTO dbo.LicenseeProduct3rd(LicenseeID,
											ProductID,
											Comm,
											Winloss,
											EffectiveDate
											)   
		SELECT  @LicenseeId AS LicenseeId
				,@ProductId AS ProductId
				,0			AS Comm
				,1 			AS Winloss
				,NULL  		AS EffectiveDate

	END 
