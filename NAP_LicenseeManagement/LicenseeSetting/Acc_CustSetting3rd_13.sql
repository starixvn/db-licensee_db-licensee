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

	SET @xml = N'<root><r>' + REPLACE(@string, @splitter, '</r><r>') + '</r></root>'

	--Create temp table containing all accounts belong to super, exclude fincance account
	CREATE TABLE #tblCust (custid INT)
	INSERT INTO #tblCust(custid)
	SELECT r.value('.','VARCHAR(12)')
	FROM @xml.nodes('//root/r') AS RECORDS(r)

	--Update Commission for HR
	UPDATE cs WITH(UPDLOCK,ROWLOCK)
	SET sdiscount = CASE WHEN roleid IN (1,4) THEN CASE WHEN sporttype = @Sporttype AND ((@Bettype = 31 AND bettype IN (31,32)) OR (@Bettype = 41 AND bettype IN (41,42)) OR (@Bettype = 51 AND bettype IN (51,52))) THEN @Discount ELSE sdiscount END
					ELSE 0 END,
		adiscount = CASE WHEN roleid IN (1,3) THEN CASE WHEN sporttype = @Sporttype AND ((@Bettype = 31 AND bettype IN (31,32)) OR (@Bettype = 41 AND bettype IN (41,42)) OR (@Bettype = 51 AND bettype IN (51,52))) THEN @Discount ELSE adiscount END
					ELSE 0 END,
		discount  = CASE WHEN roleid IN (1,2) THEN CASE WHEN sporttype = @Sporttype AND ((@Bettype = 31 AND bettype IN (31,32)) OR (@Bettype = 41 AND bettype IN (41,42)) OR (@Bettype = 51 AND bettype IN (51,52))) THEN @Discount ELSE discount END
					ELSE 0 END,
		playerdiscount = 0		 
		FROM Dep_CustSetting3rd cs 
			INNER JOIN CustInfo c ON c.custid = cs.custid
		WHERE c.custid IN (SELECT custid FROM #tblCust)

	DROP TABLE #tblCust
END





