--Step :1 rptWinlostbyleague
--SP : DBACC_Task_rptWinlostbyleague_bk.sql
--run data from DBARC.bodb_archive.dbo.bettrans_bk ---> DB052.bodb_licenseeReport.dbo.rptWinlostbyLeague
exec Task_rptWinlostbyleague_bk '2014-01-01'

exec Task_rptWinlostbyleague_bk '2014-01-02'

exec Task_rptWinlostbyleague_bk '2014-01-03'


