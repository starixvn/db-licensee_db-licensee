/*<info serverAlias="DBEXT-bodb02" executers="bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Lrf_CheckBelonging_GetAgentInfo]
	@CustId		INT		= 0,
	@TransId	BIGINT	= NULL
AS

/*
	Created: 20190730@Amanda
	Description: LAP - Get agent info which customer/bet ticket belongs to
	DB: DBEXT.bodb02

	Revisions:
		- 20190730@Amanda: Create SP to replace SP Lrf_CustomerSelCheckBelonging[Redmine: #112658]
		- 20200714@Hogan: Add check transid in bettransRnG table [RedmineID: #137290]
		- 20210727@Kos: Add custid checking [RedmineID: #158106]
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @Recommend	INT

	IF ISNULL(@TransId, 0) <> 0
	BEGIN
		IF ISNULL(@CustId, 0) <> 0
		BEGIN
			SELECT @Recommend = recommend
			FROM dbo.bettrans WITH (NOLOCK)
			WHERE transid = @TransId AND custid = @CustId

			IF @Recommend IS NULL
			BEGIN
				SELECT @Recommend = recommend
				FROM dbo.bettrans14 WITH (NOLOCK)
				WHERE transid = @TransId AND custid = @CustId
			END

			IF @Recommend IS NULL
			BEGIN
				SELECT @Recommend = recommend
				FROM DBARC.bodb_archive.dbo.Bettrans_bk WITH (NOLOCK)
				WHERE transid = @TransId AND custid = @CustId
			END

			IF @Recommend IS NULL
			BEGIN
				SELECT @Recommend = recommend
				FROM dbo.bettransRnG WITH (NOLOCK)
				WHERE transid = @TransId AND custid = @CustId
			END

			IF @Recommend IS NULL
			BEGIN
				SELECT @Recommend = recommend
				FROM dbo.bettransRnG14 WITH (NOLOCK)
				WHERE transid = @TransId AND custid = @CustId
			END

			IF @Recommend IS NULL
			BEGIN
				SELECT @Recommend = recommend
				FROM DBARC.bodb_Archive.dbo.bettransRnG_bk WITH (NOLOCK)
				WHERE transid = @TransId AND custid = @CustId
			END
		END
		ELSE
		BEGIN
			SELECT @Recommend = recommend
			FROM dbo.bettrans WITH (NOLOCK)
			WHERE transid = @TransId

			IF @Recommend IS NULL
			BEGIN
				SELECT @Recommend = recommend
				FROM dbo.bettrans14 WITH (NOLOCK)
				WHERE transid = @TransId
			END

			IF @Recommend IS NULL
			BEGIN
				SELECT @Recommend = recommend
				FROM DBARC.bodb_archive.dbo.Bettrans_bk WITH (NOLOCK)
				WHERE transid = @TransId
			END

			IF @Recommend IS NULL
			BEGIN
				SELECT @Recommend = recommend
				FROM dbo.bettransRnG WITH (NOLOCK)
				WHERE transid = @TransId
			END

			IF @Recommend IS NULL
			BEGIN
				SELECT @Recommend = recommend
				FROM dbo.bettransRnG14 WITH (NOLOCK)
				WHERE transid = @TransId
			END

			IF @Recommend IS NULL
			BEGIN
				SELECT @Recommend = recommend
				FROM DBARC.bodb_Archive.dbo.bettransRnG_bk WITH (NOLOCK)
				WHERE transid = @TransId
			END
		END
	END
	ELSE
	BEGIN
		SELECT @Recommend = recommend
		FROM dbo.custinfo WITH (NOLOCK)
		WHERE custid = @CustId AND roleid = 1	-- member
	END

	IF @Recommend IS NOT NULL
	BEGIN
		SELECT
			custid,
			currency AS CurrencyId
		FROM dbo.custinfo WITH (NOLOCK)
		WHERE custid = @Recommend AND roleid = 2	-- agent
	END
	ELSE
	BEGIN
		SELECT
			0 AS CustId,
			0 AS CurrencyId
	END
END
GO