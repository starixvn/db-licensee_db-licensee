USE [bodb_licensee]
GO
 

ALTER FUNCTION [dbo].[LRF_f_Products3rd] (@Products VARCHAR(1000))
RETURNS @tbProducts TABLE (ProductID INT, InvoiceProductID INT, ProductPrefix VARCHAR(10), ProductName VARCHAR(100))
AS
/*  Created: 20150129@Florent  
    Task : Get Product Information
    DB: DB052/bodb_Licensee  
    Revision : - 20160915@Jim: hard-code for testing Colossus Bets on UAT
    Param's Explanation:       
	select * FROM dbo.LRF_f_Products3rd('NG,SB')
*/

BEGIN     
	IF ISNULL(@Products,'') = ''
		RETURN

	IF CHARINDEX( 'SB', @Products) <> 0
	BEGIN
		INSERT INTO @tbProducts(ProductID, ProductPrefix, ProductName)
		SELECT 0, 'SB', 'SportsBook'				
	END

	SELECT @Products = REPLACE(@Products, 'SB','')
	BEGIN
		INSERT INTO @tbProducts(ProductID, ProductPrefix, ProductName)
		SELECT p.Productid, p.ProductPrefix, p.ProductName
		FROM dbo.strSplit(@Products,',') s
			LEFT JOIN bodb_licensee.dbo.Product3rd p WITH(NOLOCK) ON s.val = p.ProductPrefix
	END

	UPDATE @tbProducts
	SET InvoiceProductID = ProductID + 1
	IF   (CHARINDEX('CB',@Products)>0 )
		BEGIN 
			INSERT INTO @tbProducts (ProductID, ProductPrefix, ProductName)
			SELECT 15,'CB','Colossus Bets'
		END
	DELETE @tbProducts WHERE ProductID IS NULL
	RETURN
END