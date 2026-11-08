import java.io.*;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.*;
import java.util.regex.Matcher;
import java.util.regex.Pattern;
import java.util.stream.Collectors;
import java.util.stream.Stream;

/**
 * Script for generating Client-Side Buildouts from reading of
 * Server-Side Buildout Data Tables and Template Files. Standalone
 * script with only Java 11 as dependency.
 *
 * @author Aconite
 * @since August 2022
 */
public class ClientBuildoutGenerator
{

    /** path to compiled client data appearance directory (where we'll find *.pob files) */
    private static final String CLIENT_DATA_PATH = "../dsrc/sku.0/sys.shared/compiled/game/appearance/";
    /** path to sys.server *.tpf files */
    private static final String SERVER_TEMPLATE_PATH = "../dsrc/sku.0/sys.server/compiled/game/object/";
    /** path to sys.shared *.tpf files */
    private static final String SHARED_TEMPLATE_PATH = "../dsrc/sku.0/sys.shared/compiled/game/object/";
    /** path to server buildout datatables */
    private static final String SERVER_BUILDOUT_PATH = "../dsrc/sku.0/sys.server/compiled/game/datatables/buildout/";
    /** path to shared buildout datatables */
    private static final String SHARED_BUILDOUT_PATH = "../dsrc/sku.0/sys.shared/compiled/game/datatables/buildout/";
    /** path to sys.client dsrc for client datatables to be written */
    private static final String CLIENT_DATA_SRC_PATH = "../dsrc/sku.0/sys.client/compiled/game/";
    /** map of pob templates to their respective portal object crc32s */
    protected static final HashMap<String, Long> POB_CRC_VALUES = new HashMap<>();
    /** map of object templates and whether they have the VF_Player View Flag */
    protected static final HashMap<String, Boolean> VIEW_FLAGS = new HashMap<>();
    /** map of server object templates and their respective UR_FAR Update Radi */
    protected static final HashMap<String, Float> UPDATE_RADI = new HashMap<>();
    /** map of server object templates and their shared template counterparts */
    protected static final HashMap<String, String> SHARED_TEMPLATES = new HashMap<>();
    /** map of shared object templates and their pob file names */
    protected static final HashMap<String, String> TEMPLATE_TO_POB = new HashMap<>();
    /** set of the names of buildout files to compile from the buildout area tables */
    protected static final HashSet<String> BUILDOUTS_TO_COMPILE = new HashSet<>();
    /** pattern for pulling data encased in quotation marks */
    private static final Pattern QUOTES_PTX = Pattern.compile("\"([^\"]*)\"");
    /** reference for when we started to benchmark total build time performance */
    private static final long START_TIME = System.currentTimeMillis();

    /**
     * Runs this script. Valid arguments:
     * (none) runs and builds all server-side buildout tables to client-side buildout tables
     * -d will write debug files of each map we read into memory when running the script
     */
    public static void main(String[] args)
    {
        final List<String> switches = Arrays.asList(args);

        loadPortalObjectTemplates();
        loadServerTemplateData();
        loadSharedTemplateData();
        identifyBuildoutsForCompile();

        if(switches.contains("-d"))
        {
            try
            {
                System.out.println("Writing debug data.");
                Files.write(Path.of("pob_crc_values.tab"), POB_CRC_VALUES.entrySet().stream().map(e -> e.getKey() + "\t" + e.getValue()).collect(Collectors.toList()));
                Files.write(Path.of("view_flags.tab"), VIEW_FLAGS.entrySet().stream().map(e -> e.getKey() + "\t" + e.getValue()).collect(Collectors.toList()));
                Files.write(Path.of("update_radi.tab"), UPDATE_RADI.entrySet().stream().map(e -> e.getKey() + "\t" + e.getValue()).collect(Collectors.toList()));
                Files.write(Path.of("shared_templates.tab"), SHARED_TEMPLATES.entrySet().stream().map(e -> e.getKey() + "\t" + e.getValue()).collect(Collectors.toList()));
                Files.write(Path.of("template_to_pob.tab"), TEMPLATE_TO_POB.entrySet().stream().map(e -> e.getKey() + "\t" + e.getValue()).collect(Collectors.toList()));
                //Files.write(Path.of("buildouts_to_compile.tab"), BUILDOUTS_TO_COMPILE.stream().toList());
            }
            catch (IOException e)
            {
                e.printStackTrace();
                System.exit(-1);
            }
        }

        iterateServerBuildoutTables();

        System.out.println("***FINISHED*** build.ClientBuildoutGenerator completed in "+
                (System.currentTimeMillis() - START_TIME)+"ms!");
    }

    /**
     * reads all found *.pob files to store their CRC templates in memory
     * for fast building of Client-Side Buildouts
     */
    private static void loadPortalObjectTemplates()
    {
        final long start = System.currentTimeMillis();
        System.out.println("Starting to load Portal Object Templates...");
        final HashSet<Path> files = gatherForCompile(CLIENT_DATA_PATH, ".pob");
        for (Path path : files)
        {
            try
            {
                // get bytes for our search phase (CRC TAG3) and the pob file itself
                final byte[] seek = "CRC ".getBytes(StandardCharsets.UTF_8);
                final byte[] file = Files.readAllBytes(path);
                // find byte position of CRC TAG3 in file
                int pos = -1;
                for(int i = 0; i < (file.length - seek.length + 1); i++)
                {
                    boolean found = true;
                    for(int j = 0; j < seek.length; j++)
                    {
                        if(file[i+j] != seek[j])
                        {
                            found = false;
                            break;
                        }
                    }
                    if(found)
                    {
                        pos = i;
                    }
                }
                if(pos > -1)
                {
                    // from the position where we found the TAG3 CRC
                    // skip the tag3 (4 bytes) and the size of chunk (4 bytes)
                    // so all we have left is the remaining 4 bytes that make up the
                    // uint32 representing the crc value
                    POB_CRC_VALUES.put(path.getFileName().toString(), getUnsignedInt32(file, pos + 8));
                }
                else
                {
                    System.out.println("WARNING: Didn't find CRC when looking for it in POB file "+path.getFileName());
                }
            }
            catch (IOException e)
            {
                e.printStackTrace();
                System.exit(-1);
            }
        }
        final long stop = System.currentTimeMillis();
        System.out.println("Finished loading Portal Object Templates (took "+(stop-start)+"ms)!");
    }

    /**
     * reads all sys.server *.tpf files to find their update radius (UR_FAR)
     * template value, their shared template value, and their view flags (e.g., VF_Player)
     * and then add them to the in-memory maps for writing reference
     */
    private static void loadServerTemplateData()
    {
        final long start = System.currentTimeMillis();
        System.out.println("Starting to load Server Template Data...");
        final HashSet<Path> files = gatherForCompile(SERVER_TEMPLATE_PATH, ".tpf");
        for (Path path : files)
        {
            try
            {
                // make sure we aren't at a directory
                if(path.toFile().isDirectory())
                {
                    continue;
                }
                // read all lines of the template file
                List<String> lines = Files.readAllLines(path, StandardCharsets.UTF_8);
                // track whether this tpf had a UR_far value set in it
                boolean foundFarValue = false;
                // track whether we found the shared template for this file
                boolean foundSharedTemplate = false;
                // track whether we found the visibility flag for this file
                boolean foundVisibilityFlag = false;
                // recursively look for the UR_far value in this tpf or its bases
                // and grab the shared file name while we're in here
                Path workingPath = path;
                while(!workingPath.toString().endsWith("game\\\\object") ||
                        (!foundSharedTemplate && !foundFarValue && !foundVisibilityFlag))
                {
                    String base = "";
                    for (String line : lines)
                    {
                        line = line.stripLeading(); // some lines start with tables/spaces because why not be inconsistent
                        // get the base of the file
                        if(line.startsWith("@base"))
                        {
                            base = line.replace("@base ", "").replace(".iff", ".tpf");
                        }
                        // get the shared template of this file
                        if(!foundSharedTemplate && line.startsWith("sharedTemplate"))
                        {
                            final Matcher match = QUOTES_PTX.matcher(line);
                            while(match.find())
                            {
                                final String sharedTemplate = match.group();
                                SHARED_TEMPLATES.put(cleanPath(path).replace("tpf", "iff"), sharedTemplate.replace("\"", ""));
                                foundSharedTemplate = true;
                            }
                        }
                        if(!foundFarValue && line.startsWith("updateRanges[UR_far]"))
                        {
                            final int farValue = Integer.parseInt(line.replaceAll("[^0-9]", ""));
                            UPDATE_RADI.put(cleanPath(path).replace("tpf", "iff"), (float) farValue);
                            foundFarValue = true;
                        }
                        if(!foundVisibilityFlag && line.startsWith("visibleFlags"))
                        {
                            // GM flag but no Player flag = not visible to players
                            if(line.contains("VF_gm"))
                            {
                                VIEW_FLAGS.put(cleanPath(path).replace("tpf", "iff"), line.contains("VF_player"));
                                foundVisibilityFlag = true;
                            }
                            // just player flag is still visible to players
                            else if (line.contains("VF_player"))
                            {
                                VIEW_FLAGS.put(cleanPath(path).replace("tpf", "iff"), true);
                                foundVisibilityFlag = true;
                            }
                        }
                    }
                    // get the path to the @base parent file
                    workingPath = Path.of((path.toString().split("game\\\\object")[0] + "game/" + base.strip())
                            .strip().replace("/", "\\"));
                    if(workingPath.toFile().isDirectory()) // break once we get to a directory only
                    {
                        break;
                    }
                    // read the parent file
                    lines = Files.readAllLines(workingPath);
                }
            }
            catch (IOException e)
            {
                e.printStackTrace();
                System.exit(-1);
            }
        }
        final long stop = System.currentTimeMillis();
        System.out.println("Finished loading Server Template Data (took "+(stop-start)+"ms)!");
    }

    /**
     * reads all sys.shared *.tpf files to find their portal layout file name (if any)
     * to store in the in-memory maps for writing reference
     */
    public static void loadSharedTemplateData()
    {
        long start = System.currentTimeMillis();
        System.out.println("Starting to load Shared Template Data...");
        final HashSet<Path> files = gatherForCompile(SHARED_TEMPLATE_PATH, ".tpf");
        for (Path path : files)
        {
            try
            {
                // read all lines of the template file
                List<String> lines = Files.readAllLines(path, StandardCharsets.UTF_8);
                for(String line : lines)
                {
                    // find pob appearance path if it exists and store it
                    if(line.startsWith("portalLayoutFilename"))
                    {
                        final Matcher match = QUOTES_PTX.matcher(line);
                        while(match.find())
                        {
                            final String portalLayoutFilename = match.group()
                                    .replace("appearance/", "")
                                    .replace("appearance\\", "") // because SOE cannot be consistent
                                    .replace("\"", "");
                            TEMPLATE_TO_POB.put(cleanPath(path).replace("tpf", "iff"), portalLayoutFilename);
                        }
                    }
                }
            }
            catch (IOException e)
            {
                e.printStackTrace();
                System.exit(-1);
            }
        }
        final long stop = System.currentTimeMillis();
        System.out.println("Finished loading Shared Template Data (took "+(stop-start)+"ms)!");
    }

    /**
     * Creates a list of which buildout files should be compiled, which are all buildouts
     * that don't require a server event (eventRequired) as those buildouts are server-side only.
     */
    public static void identifyBuildoutsForCompile()
    {
        long start = System.currentTimeMillis();
        System.out.println("Identifying which Buildouts should be written.");
        final HashSet<Path> files = gatherForCompile(SHARED_BUILDOUT_PATH, ".tab");
        for(Path path : files)
        {
            if(path.toFile().getName().startsWith("areas_"))
            {
                try
                {
                    List<String> lines = Files.readAllLines(path);
                    for(int i = 2; i < lines.size(); i++) // skip header rows
                    {
                        // eventRequired column is 2nd to last, so instead of iterating through the row
                        // and parsing, go from the end of the table backwards
                        final String line = lines.get(i);
                        if(line.substring(0, line.lastIndexOf("\t")).endsWith("\t"))
                        {
                            BUILDOUTS_TO_COMPILE.add(line.split("\t")[0] + ".tab");
                        }
                    }
                }
                catch (IOException e)
                {
                    e.printStackTrace();
                    System.exit(-1);
                }
            }
        }
        final long stop = System.currentTimeMillis();
        System.out.println("Finished identifying Buildout files for writing (took "+(stop-start)+"ms)!");
    }

    /**
     * iterates the server-side buildout tables to gather their rows
     * (instantiated as build.ServerBuildoutEntry objects) and then for each server-side
     * buildout table, creates a corresponding client side buildout table
     */
    public static void iterateServerBuildoutTables()
    {
        System.out.println("Starting to iterate Server Buildout Tables...");
        final HashSet<Path> files = gatherForCompile(SERVER_BUILDOUT_PATH, ".tab")
                .stream().filter(f -> BUILDOUTS_TO_COMPILE.contains(f.getFileName().toString()))
                .collect(Collectors.toCollection(HashSet::new));
        for(Path path : files)
        {
            final LinkedHashSet<ServerBuildoutEntry> entries = new LinkedHashSet<>();
            final File file = path.toFile();
            if(file.isFile() && file.canRead())
            {
                try
                {
                    List<String> lines = Files.readAllLines(path);
                    for(int i = 2; i < lines.size(); i++) // skip lines 0 & 1 (column names and data types)
                    {
                        final ServerBuildoutEntry entry = new ServerBuildoutEntry(file.toString(), lines.get(i));
                        // check that both this template is regarded as having the VF_Player visibility flag
                        // and that the server template has defined a shared template, and if both are true,
                        // then we will add this entry for writing to the client buildout table
                        if(VIEW_FLAGS.getOrDefault(entry.server_template_crc, false) &&
                                !SHARED_TEMPLATES.getOrDefault(entry.server_template_crc, "").equals(""))
                        {
                            entries.add(entry);
                        }
                    }
                }
                catch (IOException e)
                {
                    e.printStackTrace();
                    System.exit(-1);
                }
                if(entries.size() < 1)
                {
                    System.out.println("ERROR: Buildout "+cleanPath(path) + " has NO client-visible objects in it which means it will generate a blank table that can't compile!");
                    //System.exit(-1);
                }
                writeClientBuildoutTable(path, entries);
            }
        }
        System.out.println("Finished iterating Server Buildout tables!");
    }

    /**
     * Takes a read server-buildout and writes it into a client-side buildout by
     * instantiating build.ClientBuildoutEntry objects for each row and then writing those
     *
     * @param buildout the path to the server-side buildout this request originated from
     * @param entries the build.ServerBuildoutEntry objects from reading that server buildout file
     */
    public static void writeClientBuildoutTable(final Path buildout, final HashSet<ServerBuildoutEntry> entries)
    {
        final long start = System.currentTimeMillis();
        long size = 0;
        final String cleanPath = cleanPath((buildout));
        System.out.println("Beginning to write Client Buildout Table "+cleanPath);
        final File clientBuildoutFile = new File(CLIENT_DATA_SRC_PATH + cleanPath);
        if(!clientBuildoutFile.exists())
        {
            // make dirs if necessary, we don't care if this fails because
            // the directories already exist if so (or we can't write, but
            // we'll fail later if that's the issue)
            //noinspection ResultOfMethodCallIgnored
            clientBuildoutFile.getParentFile().mkdirs();
        }
        try
        {
            final List<String> lines = new ArrayList<>();
            final String header = "objid\tcontainer\ttype\tshared_template_crc\tcell_index\tpx\tpy\tpz\tqw\tqx\tqy\tqz\tradius\tportal_layout_crc";
            final String types = "i\ti\ti\th\ti\tf\tf\tf\tf\tf\tf\tf\tf\ti";
            lines.add(header);
            lines.add(types);
            for(ServerBuildoutEntry entry : entries)
            {
                lines.add(new ClientBuildoutEntry(entry).toString());
            }
            final Path path = clientBuildoutFile.toPath();
            Files.write(path, lines, StandardCharsets.UTF_8);
            size = Files.size(path);
        }
        catch (IOException e)
        {
            e.printStackTrace();
            System.exit(-1);
        }
        final long stop = System.currentTimeMillis();
        System.out.println("Finished writing Client Buildout Table "+cleanPath+" (took "+(stop-start)+"ms) (size "+size+" bytes)");
    }

    /**
     * Gathers all possible files to be called to the compilation tools
     *
     * @param targetPath the start of the path to search
     * @param targetExtension the file extension to search for
     * @return Set of file paths froms search
     */
    private static HashSet<Path> gatherForCompile(final String targetPath, final String targetExtension)
    {
        HashSet<Path> files = new HashSet<>();
        try(Stream<Path> entries = Files.walk(Paths.get(targetPath)))
        {
            if(targetExtension != null && targetExtension.length() > 0)
            {
                entries.filter(f -> f.getFileName().toString().endsWith(targetExtension))
                        .collect(Collectors.toCollection(() -> files));
            }
            else
            {
                entries.collect(Collectors.toCollection(() -> files));
            }
        }
        catch (IOException e)
        {
            e.printStackTrace();
        }
        return files;
    }

    /**
     * Reads an unsigned integer 32 (4 bytes) from byte array
     *
     * @param input byte[] to search
     * @param loc loc to start the search
     * @return properly read and formatted uint32
     */
    private static long getUnsignedInt32(byte[] input, int loc)
    {
        return ((long) (input[loc + 3] & 0xFF) << 24) | (long) ((input[loc + 2] & 0xFF) << 16)
                | (long) ((input[loc + 1] & 0xFF) << 8) | (long) (input[loc] & 0xFF);
    }

    /**
     * Cleans a win32 System Path into the format appropriate
     * for searching and packing into Data Tables
     * @param path the path to clean
     * @return the cleaned path
     */
    private static String cleanPath(final Path path)
    {
        return path.toString().split("compiled\\\\game\\\\")[1].replace("\\", "/");
    }

    /**
     * Iterates through server buildouts to format them properly such that they can
     * be processed by this utility. This routine only needs to be called once to re-format
     * the filler buildouts that only contain a single object.
     */
    private static void cleanPlaceholderServerBuildouts()
    {
        final HashSet<Path> b = gatherForCompile(SERVER_BUILDOUT_PATH, ".tab");
        List<File> badFilesList = new ArrayList<>();
        for(Path path : b)
        {
            try
            {
                List<String> lines = Files.readAllLines(path);
                if(lines.get(0).split("\t").length < 13)
                {
                    if(lines.size() == 3 && lines.get(2).contains("object/building/kashyyyk/thm_kash_rodian_bannerpole_s01.iff"))
                    {
                        System.out.println("Identified bad buildout for fixing: "+path.toFile().getName());
                        badFilesList.add(path.toFile());
                    }
                }
            }
            catch (IOException e)
            {
                e.printStackTrace();
            }
        }
        for(File badBuildout : badFilesList)
        {
            final String header = "objid\tcontainer\tserver_template_crc\tcell_index\tpx\tpy\tpz\tqw\tqx\tqy\tqz\tscripts\tobjvars";
            final String types = "i\ti\th\ti\tf\tf\tf\tf\tf\tf\tf\ts\tp";
            final String row = "-1\t0\tobject/building/kashyyyk/thm_kash_rodian_bannerpole_s01.iff\t0\t0\t195\t0\t0\t0\t0\t0\t\t$|";
            final List<String> lines = Arrays.asList(header, types, row);
            try
            {
                Files.write(badBuildout.toPath(), lines, StandardCharsets.UTF_8);
            }
            catch (IOException e)
            {
                e.printStackTrace();
                System.exit(-1);
            }
            System.out.println("Fixed placeholder buildout "+badBuildout.getName());
        }
    }
}

/**
 * Object representation of a singular entry in a Server Buildout Datatable
 */
class ServerBuildoutEntry
{
    long objid;
    int container;
    String server_template_crc;
    int cell_index;
    float px;
    float py;
    float pz;
    float qw;
    float qx;
    float qy;
    float qz;

    ServerBuildoutEntry(String fileName, String line)
    {
        final String[] data = line.split("\t");
        try
        {
            if(data.length >= 10)
            {
                this.objid = Long.parseLong(data[0]);
                this.container = data[1].equals("") ? 0 : Integer.parseInt(data[1]);
                this.server_template_crc = data[2];
                this.cell_index = data[3].equals("") ? 0 : Integer.parseInt(data[3]);
                this.px = Float.parseFloat(data[4]);
                this.py = Float.parseFloat(data[5]);
                this.pz = Float.parseFloat(data[6]);
                this.qw = Float.parseFloat(data[7]);
                this.qx = Float.parseFloat(data[8]);
                this.qy = Float.parseFloat(data[9]);
                this.qz = Float.parseFloat(data[10]);
            }
            else
            {
                System.out.println("WARNING: Tried to instantiate build.ServerBuildoutEntry with less than 10 data points in file"+ fileName);
            }
        }
        catch (NumberFormatException ignore)
        {
        }
    }
}

/**
 * Object representation of a singular entry in a Client Buildout Datatable
 */
class ClientBuildoutEntry extends ClientBuildoutGenerator
{
    long objid;
    int container;
    int type;
    String shared_template_crc;
    int cell_index;
    float px;
    float py;
    float pz;
    float qw;
    float qx;
    float qy;
    float qz;
    float radius;
    long portal_layout_crc;

    /**
     * Instantiate a build.ClientBuildoutEntry from a given build.ServerBuildoutEntry
     */
    ClientBuildoutEntry(ServerBuildoutEntry entry)
    {
        this.objid = entry.objid;
        this.container = entry.container;
        this.type = 0; // the "type" field is not read by WorldSnapshot.cpp anymore, but we'll include it empty for good measure
        this.shared_template_crc = SHARED_TEMPLATES.get(entry.server_template_crc);
        this.cell_index = entry.cell_index;
        this.px = entry.px;
        this.py = entry.py;
        this.pz = entry.pz;
        this.qw = entry.qw;
        this.qx = entry.qx;
        this.qy = entry.qy;
        this.qz = entry.qz;
        this.radius = UPDATE_RADI.get(entry.server_template_crc);
        // if a server-side entry stores the portal property crc, we need to get it and populate it client-side too
        final String sharedTemplate = SHARED_TEMPLATES.get(entry.server_template_crc);
        final String pobTarget = TEMPLATE_TO_POB.getOrDefault(sharedTemplate, null);
        if(pobTarget != null && !pobTarget.equals(""))
        {
            this.portal_layout_crc = POB_CRC_VALUES.get(pobTarget);
        }
        else
        {
            this.portal_layout_crc = 0;
        }
    }

    /**
     * @return String of this Client Data Table Entry formatted for insertion into a tab file
     */
    @Override
    public String toString()
    {
        return this.objid + "\t" +
                this.container + "\t" +
                this.type + "\t" +
                this.shared_template_crc + "\t" +
                this.cell_index + "\t" +
                this.px + "\t" +
                this.py + "\t" +
                this.pz + "\t" +
                this.qw + "\t" +
                this.qx + "\t" +
                this.qy + "\t" +
                this.qz + "\t" +
                this.radius + "\t" +
                this.portal_layout_crc;
    }
}
