ALTER PROCEDURE [dbo].[Acc_CustSetting3rd_13]
	@srecommend INT
	,@Sporttype INT
	,@Bettype INT
	,@Discount DECIMAL(9,8)
	,@ErrCode INT = 0 OUTPUT
    ,@ErrMsg NVARCHAR(4000) = '' OUTPUT
AS
/*
	Created: Elodie
	Date: 20150108
	Task : Licensee Setting Configuration - Update Commission [#6304]
	DB: DBCUST/CustDB
	Original:

	Revisions:

	Param's Explanation:
		
*/ 
BEGIN

	SET NOCOUNT ON
	
	IF (SELECT COUNT(1) FROM sys.objects WHERE name IN ('Dep_Custsetting3rd','custinfo') AND type = 'U') <> 2
		RETURN
	
	--Create temp table containing all accounts belong to super, exclude fincance account
	CREATE TABLE #tblCust(custid INT PRIMARY KEY, isfinished BIT DEFAULT(0))
	INSERT INTO #tblCust(custid)
	SELECT custid
	FROM custinfo WITH(NOLOCK)	
	WHERE srecommend = @srecommend
			AND mrecommend NOT IN (SELECT custid FROM custinfo WITH(NOLOCK)
									WHERE srecommend = @srecommend AND username LIKE '%Acc%' AND roleid=3)

	BEGIN TRY
		DECLARE @rowcnt INT
		WHILE (1=1)
		BEGIN
			UPDATE TOP (10000) #tblCust
			SET isfinished = 1
			FROM #tblCust
			WHERE isfinished = 0

			SELECT @rowcnt = @@rowcount

			IF @Bettype = 31
			BEGIN
				--Update Commission for HR
				UPDATE cs WITH(UPDLOCK,ROWLOCK)
				SET sdiscount = CASE WHEN roleid IN (1,4) THEN @Discount ELSE 0 END,
					adiscount = CASE WHEN roleid IN (1,3) THEN @Discount ELSE 0 END,
					discount  = CASE WHEN roleid IN (1,2) THEN @Discount ELSE 0 END,
					playerdiscount = 0		 
					FROM Dep_CustSetting3rd cs 
						INNER JOIN CustInfo c ON c.custid = cs.custid
						INNER JOIN #tblCust tmp ON c.custid = tmp.custid
					WHERE sporttype = @Sporttype AND bettype IN (31,32)
			END

			IF @Bettype = 41
			BEGIN
				--Update Commission for HR
				UPDATE cs WITH(UPDLOCK,ROWLOCK)
				SET sdiscount = CASE WHEN roleid IN (1,4) THEN @Discount ELSE 0 END,
					adiscount = CASE WHEN roleid IN (1,3) THEN @Discount ELSE 0 END,
					discount  = CASE WHEN roleid IN (1,2) THEN @Discount ELSE 0 END,
					playerdiscount = 0		 
					FROM Dep_CustSetting3rd cs 
						INNER JOIN CustInfo c ON c.custid = cs.custid
						INNER JOIN #tblCust tmp ON c.custid = tmp.custid
					WHERE sporttype = @Sporttype AND bettype IN (41,42)
			END

			IF @Bettype = 51
			BEGIN
				--Update Commission for HR
				UPDATE cs WITH(UPDLOCK,ROWLOCK)
				SET sdiscount = CASE WHEN roleid IN (1,4) THEN @Discount ELSE 0 END,
					adiscount = CASE WHEN roleid IN (1,3) THEN @Discount ELSE 0 END,
					discount  = CASE WHEN roleid IN (1,2) THEN @Discount ELSE 0 END,
					playerdiscount = 0		 
					FROM Dep_CustSetting3rd cs 
						INNER JOIN CustInfo c ON c.custid = cs.custid
						INNER JOIN #tblCust tmp ON c.custid = tmp.custid
					WHERE sporttype = @Sporttype AND bettype IN (51,52)
			END

			IF @rowcnt < 10000 BREAK

			WAITFOR DELAY '00:00:01'
		END

		DROP TABLE #tblCust
	END TRY
	BEGIN CATCH
		SELECT @ErrMsg = ERROR_MESSAGE(), @ErrCode  = ERROR_NUMBER()   					
		DROP TABLE #tblCust
		RETURN
	END CATCH	
END





