ALTER PROCEDURE [dbo].[Lrf_CustomerSelCheckBelonging]
	@LicenseeID INT,
	@custid INT = 0,
	@transid bigint = NULL,
	@status BIT OUTPUT
AS
/*
Created: Henry@20101210
Task: check downline belonging
DB: DB052.bodb02
Original:  [Age_CustomerSelCheckBelonging]
	
Revisions:
   - 20110406: check customer by transid/refno
*/
SET NOCOUNT ON

DECLARE @roleid INT
DECLARE @recommend INT

if isnull(@transid,0)<>0
begin
	SELECT @recommend = recommend from bettrans with (nolock) WHERE transid = @transid

	if @recommend is NULL
		SELECT @recommend = recommend from bettrans14 with (nolock) WHERE transid = @transid

	if @recommend is NULL
		SELECT @recommend = recommend from db06.bodb_archive.dbo.Bettrans_bk with (nolock) WHERE transid = @transid
		
	--check agent belongs to licensee
	SELECT 
		@roleid = c.RoleID
	from bodb_Licensee.dbo.LicenseeCust lc (nolock)
	inner join custinfo c with (nolock) on lc.custid = c.custid
	WHERE lc.LicenseeID = @LicenseeID
	AND lc.custid = @recommend	
		
END
ELSE
begin
	--check agent belongs to licensee
	SELECT 
		@roleid = c.RoleID
	from bodb_Licensee.dbo.LicenseeCust lc (nolock)
	inner join custinfo c with (nolock) on lc.custid = c.custid
	WHERE lc.LicenseeID = @LicenseeID
	AND lc.custid = @custid
	
	if isnull(@roleid,0) = 0
	begin
		--check member belongs to agent of a licensee
		SELECT 
			@roleid = c.RoleID
		from custinfo c with (nolock)
		WHERE 
			c.custid = @custid
			AND c.recommend in
			(
				SELECT custid from bodb_Licensee.dbo.LicenseeCust (nolock)
				WHERE LicenseeID = @LicenseeID
			)
	END
END



SELECT @roleid = isnull(@roleid, 0)

if isnull(@roleid, 0) = 0 
	SELECT @status = 0
ELSE
	SELECT @status = 1


GO
GRANT EXECUTE ON [dbo].[Lrf_CustomerSelCheckBelonging] TO [bodbLicenseeNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_CustomerSelCheckBelonging] TO [vnteam]