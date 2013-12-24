ALTER PROCEDURE [dbo].[Lrf_CustomerSelCheckBelonging]
	@LicenseeID int,
	@custid int = 0,
	@transid bigint = NULL,
	@status bit OUTPUT
AS
/*
Created: Henry@20101210
Task: check downline belonging
DB: DB052.bodb02
Original:  [Age_CustomerSelCheckBelonging]
	
Revisions:
   - 20110406: check customer by transid/refno
   - 20131218@winnie : change db02 to DBARC Alias
*/
SET NOCOUNT ON

declare @roleid int
declare @recommend int

if isnull(@transid,0)<>0
begin
	select @recommend = recommend from bettrans with (nolock) where transid = @transid

	if @recommend is NULL
		select @recommend = recommend from bettrans14 with (nolock) where transid = @transid

	if @recommend is NULL
		select @recommend = recommend from  DBARC.bodb_archive.dbo.Bettrans_bk with (nolock) where transid = @transid
		
	--check agent belongs to licensee
	select 
		@roleid = c.RoleID
	from bodb_Licensee.dbo.LicenseeCust lc (nolock)
	inner join custinfo c with (nolock) on lc.custid = c.custid
	where lc.LicenseeID = @LicenseeID
	and lc.custid = @recommend	
		
end
else
begin
	--check agent belongs to licensee
	select 
		@roleid = c.RoleID
	from bodb_Licensee.dbo.LicenseeCust lc (nolock)
	inner join custinfo c with (nolock) on lc.custid = c.custid
	where lc.LicenseeID = @LicenseeID
	and lc.custid = @custid
	
	if isnull(@roleid,0) = 0
	begin
		--check member belongs to agent of a licensee
		select 
			@roleid = c.RoleID
		from custinfo c with (nolock)
		where 
			c.custid = @custid
			and c.recommend in
			(
				select custid from bodb_Licensee.dbo.LicenseeCust (nolock)
				where LicenseeID = @LicenseeID
			)
	end
end



select @roleid = isnull(@roleid, 0)

if isnull(@roleid, 0) = 0 
	select @status = 0
else
	select @status = 1
GO
GRANT EXECUTE ON [dbo].[Lrf_CustomerSelCheckBelonging] TO [bodbLicenseeNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_CustomerSelCheckBelonging] TO [vnteam]