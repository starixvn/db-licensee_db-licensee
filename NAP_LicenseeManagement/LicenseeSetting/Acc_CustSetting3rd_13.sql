ALTER PROCEDURE [dbo].[Acc_CustSetting3rd_13]
	@ids VARCHAR(MAX)
	,@Sporttype INT
	,@Bettype INT
	,@Discount DECIMAL(9,8)
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
	
	DECLARE @string VARCHAR(MAX), @splitter CHAR(1), @xml XML
	SELECT @splitter = ',', @string = @ids

	SET @xml = N'<root><r i=''' + REPLACE(@string, @splitter, '''/><r i=''') + '''/></root>'

	--Create temp table containing all accounts belong to super, exclude fincance account
	CREATE TABLE #tblCust (custid INT)	
	INSERT INTO #tblCust(custid)
	SELECT r.value('./@i','INT')
	FROM @xml.nodes('//root/r') AS RECORDS(r)

	IF @Bettype = 31
	BEGIN
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

	ELSE IF @Bettype = 41
	BEGIN
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

	ELSE IF @Bettype = 51
	BEGIN
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

	DROP TABLE #tblCust
END




