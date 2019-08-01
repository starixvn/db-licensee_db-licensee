/*<info serverAlias="DBEXT-bodb02" executers="bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/
CREATE PROCEDURE [dbo].[Lrf_CheckBelonging_GetAgentInfo]
	@custId		INT = 0,
	@transId	BIGINT = NULL
AS
/*
Created: Amanda
Date: 2019-07-30
Task : Get agent info which customer/bet ticket belongs to
DB: DBEXT.bodb02
	
Revisions:
   - 20190730: Create SP to replace SP Lrf_CustomerSelCheckBelonging[redmine: #112658]
*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE @recommend	INT

	IF ISNULL(@transid,0)<>0
	BEGIN
		SELECT @recommend = recommend FROM dbo.bettrans WITH (NOLOCK) WHERE transid = @transId

		IF @recommend IS NULL
		BEGIN
			SELECT @recommend = recommend FROM dbo.bettrans14 WITH (NOLOCK) WHERE transid = @transId
		END

		IF @recommend IS NULL
		BEGIN
			SELECT @recommend = recommend FROM  DBARC.bodb_archive.dbo.Bettrans_bk WITH (NOLOCK) WHERE transid = @transId
		END
	END
	ELSE
	BEGIN
		SELECT @recommend = recommend FROM dbo.custinfo WITH (NOLOCK) WHERE custid = @custId and roleid = 1 -- member
	END
	
	IF @recommend IS NOT NULL
	BEGIN
		SELECT custid, currency AS CurrencyId FROM dbo.custinfo WITH (NOLOCK) WHERE custid = @recommend and roleid = 2 -- agent
	END
	ELSE
	BEGIN
		SELECT 0 AS CustId, 0 AS CurrencyId
	END
END
GO