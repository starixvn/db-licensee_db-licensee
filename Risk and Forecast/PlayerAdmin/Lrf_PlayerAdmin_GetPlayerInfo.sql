/*<info serverAlias="DBEXT-bodb02" executers="bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/
CREATE PROCEDURE [dbo].[Lrf_PlayerAdmin_GetPlayerInfo]
	@custId	INT = 0
AS
/*
   	Created: 20190730@Amanda
	Description: LAP - Get player info by custId
	DB: DBEXT.bodb02
   
	Revisions:
		- 20190730@Amanda: Create SP [Redmine: #112658]
*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE @result AS TABLE (
		CustId		INT,
		CurrencyId	TINYINT
	)

	INSERT INTO @result(CustId, CurrencyId)
	SELECT custid, currency FROM dbo.Customer WITH (NOLOCK) WHERE custid = @custId AND roleid = 1
	
	IF NOT EXISTS (SELECT 1 FROM @result)
	BEGIN
		INSERT INTO @result(CustId, CurrencyId)
		SELECT a.custid, c.currency
		FROM dbo.Dep_Customer_Archived a WITH (NOLOCK)
		INNER JOIN dbo.Customer c WITH (NOLOCK) ON a.Recommend = c.recommend
		WHERE a.custid = @custId AND c.roleid = 2
	END
	
	SELECT CustId, CurrencyId FROM @result
END
GO